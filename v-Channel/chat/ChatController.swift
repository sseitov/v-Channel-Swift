//
//  ChatController.swift
//  iNear
//
//  Created by Сергей Сейтов on 01.12.16.
//  Copyright © 2016 Сергей Сейтов. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD
import MessageKit
import MapKit

class ChatController: MessagesViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    var opponent:AppUser?
    var messageList: [ChatMessage] = []
    
    lazy var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTitle(opponent!.name!)
        setupBackButton()
        
        messageList = Model.shared.chatMessages(with: opponent!.uid!)
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        
        let newMessageInputBar = MessageInputBar()
        newMessageInputBar.sendButton.tintColor = UIColor.black
        newMessageInputBar.delegate = self
        messageInputBar = newMessageInputBar
        reloadInputViews()
        let item = InputBarButtonItem()
            .configure {
                $0.spacing = .fixed(10)
                $0.image = UIImage(named: "attachment")?.withRenderingMode(.alwaysTemplate)
                $0.setSize(CGSize(width: 30, height: 30), animated: true)
            }.onTouchUpInside { _ in
                self.pressAccessoryButton()
        }
        item.tintColor = UIColor.black
        
        messageInputBar.setLeftStackViewWidthConstant(to: 40, animated: false)
        messageInputBar.setStackViewItems([item], forStack: .left, animated: false)

        scrollsToBottomOnKeybordBeginsEditing = true
        maintainPositionOnKeyboardFrameChanged = true
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.newMessage(_:)),
                                               name: newMessageNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ChatController.deleteMessage(_:)),
                                               name: deleteMessageNotification,
                                               object: nil)

        messagesCollectionView.scrollToBottom()
    }
    
    @objc
    func deleteMessage(_ notify:Notification) {
        if let message = notify.object as? Message {
            let chatMessage = ChatMessage(message)
            if let index = messageList.index(where: { msg in
                return msg.messageId == chatMessage.messageId
            }) {
                messageList.remove(at: index)
                let set = IndexSet(integer: index)
                messagesCollectionView.deleteSections(set)
            }
        }
    }

    @objc
    func newMessage(_ notify:Notification) {
        if let message = notify.object as? Message {
            let chatMessage = ChatMessage(message)
            messageList.append(chatMessage)
            messagesCollectionView.insertSections([messageList.count - 1])
            messagesCollectionView.scrollToBottom()
        }
    }

    private func pressAccessoryButton() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let actionView = ActionSheet.create(
            title: "Choose Data",
            actions: ["Photo from Camera Roll", "Create photo use Camera", "My current location"],
            handler1: {
                let imagePicker = UIImagePickerController()
                imagePicker.allowsEditing = false
                imagePicker.sourceType = .photoLibrary
                imagePicker.delegate = self
                imagePicker.modalPresentationStyle = .formSheet
                imagePicker.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : MainColor, NSAttributedStringKey.font : UIFont.condensedFont(15)]
                imagePicker.navigationBar.tintColor = MainColor
                self.present(imagePicker, animated: true, completion: nil)
        }, handler2: {
            let imagePicker = UIImagePickerController()
            imagePicker.allowsEditing = false
            imagePicker.sourceType = .camera
            imagePicker.delegate = self
            imagePicker.modalPresentationStyle = .formSheet
            imagePicker.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : MainColor, NSAttributedStringKey.font : UIFont.condensedFont(15)]
            imagePicker.navigationBar.tintColor = MainColor
            self.present(imagePicker, animated: true, completion: nil)
        }, handler3: {
            SVProgressHUD.show(withStatus: "Get Location...")
            LocationManager.shared.updateLocation({ location in
                SVProgressHUD.dismiss()
                if location != nil {
                    Model.shared.sendLocationMessage(location!.coordinate, to: self.opponent!.uid!)
                } else {
                    self.showMessage("Can not get your location.")
                }
            })
        })
        
        actionView?.show()
    }
    
    // MARK: - UIImagePickerController delegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: {
            if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
                SVProgressHUD.show(withStatus: "Send...")
                Model.shared.sendImageMessage(pickedImage, to: self.opponent!.uid!, result: { error in
                    SVProgressHUD.dismiss()
                    if error != nil {
                        self.showMessage(error!.localizedDescription)
                    }
                })
            }
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func makeCall(_ sender: Any) {
        ShowCall(userName: opponent?.name, userID: opponent?.uid, callID: nil)
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPhoto" {
            let controller = segue.destination as! PhotoController
            let message = sender as! ChatMessage
            controller.date = message.sentDate
            switch message.kind {
            case .photo(let mediaItem):
                controller.image = mediaItem.image
            default:
                break
            }
        } else if segue.identifier == "showMap" {
            let controller = segue.destination as! RouteController
            let message = sender as! ChatMessage
            if message.sender.id != currentUser()!.uid! {
                controller.user = self.opponent
            } else {
                controller.user = currentUser()
            }
            switch message.kind {
            case .location(let locationItem):
                controller.userLocation = locationItem.location.coordinate
                controller.locationDate = message.sentDate
            default:
                break
            }
        }
    }
}

// MARK: - MessagesDataSource

extension ChatController: MessagesDataSource {
    
    func currentSender() -> Sender {
        return Sender(id: currentUser()!.uid!, displayName: currentUser()!.name!)
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messageList.count
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messageList[indexPath.section]
    }
    
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
/*
        if indexPath.section % 3 == 0 {
            return NSAttributedString(string: MessageKitDateFormatter.shared.string(from: message.sentDate), attributes: [NSAttributedStringKey.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedStringKey.foregroundColor: UIColor.darkGray])
        }
 */
        return nil
    }
    
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }
    
    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        
        let dateString = formatter.string(from: message.sentDate)
        return NSAttributedString(string: dateString, attributes: [NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
    
}

// MARK: - MessagesLayoutDelegate

extension ChatController: MessagesLayoutDelegate {
    
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if indexPath.section % 3 == 0 {
            return 10
        }
        return 0
    }
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
    
}

// MARK: - MessagesDisplayDelegate

extension ChatController: MessagesDisplayDelegate {
    
    // MARK: - Text Messages
    
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText
    }
    
    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedStringKey: Any] {
        return MessageLabel.defaultAttributes
    }
    
    func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        return [.url, .address, .phoneNumber, .date, .transitInformation]
    }
    
    // MARK: - All Messages
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1) : UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
    }
    
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
        //        let configurationClosure = { (view: MessageContainerView) in}
        //        return .custom(configurationClosure)
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        var avatar:Avatar?
        if message.sender.id == currentUser()!.uid! {
            avatar = Avatar(image: currentUser()?.getImage(), initials: currentUser()!.name!)
        } else {
            if let user = Model.shared.getUser(message.sender.id) {
                avatar = Avatar(image: user.getImage(), initials: user.name!)
            } else {
                let unknown = UIImage.imageWithColor(UIColor.lightGray, size: CGSize(width: 100, height: 100)).addImage(UIImage(named: "question")!)
                avatar = Avatar(image: unknown, initials: "")
            }
        }
        avatarView.set(avatar: avatar!)
    }
    
    // MARK: - Location Messages
    
    func annotationViewForLocation(message: MessageType, at indexPath: IndexPath, in messageCollectionView: MessagesCollectionView) -> MKAnnotationView? {
        let annotationView = MKAnnotationView(annotation: nil, reuseIdentifier: nil)
        if let user = Model.shared.getUser(message.sender.id) {
            annotationView.image = user.getImage()?.withSize(CGSize(width: 30, height: 30)).inCircle()
        } else {
            let pinImage = #imageLiteral(resourceName: "pin")
            annotationView.image = pinImage
            annotationView.centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
        }
        return annotationView
    }
    
    func animationBlockForLocation(message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> ((UIImageView) -> Void)? {
        return { view in
            view.layer.transform = CATransform3DMakeScale(0, 0, 0)
            view.alpha = 0.0
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [], animations: {
                view.layer.transform = CATransform3DIdentity
                view.alpha = 1.0
            }, completion: nil)
        }
    }
    
    func snapshotOptionsForLocation(message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LocationMessageSnapshotOptions {
        
        return LocationMessageSnapshotOptions()
    }
}

// MARK: - MessageCellDelegate

extension ChatController: MessageCellDelegate {
    
    func didTapAvatar(in cell: MessageCollectionViewCell) {
        
    }
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        if let indexPath = messagesCollectionView.indexPath(for: cell) {
            tapOnMessage(messageList[indexPath.section])
        }
    }
    
    func didTapCellTopLabel(in cell: MessageCollectionViewCell) {
    }
    
    func didTapMessageTopLabel(in cell: MessageCollectionViewCell) {
    }
    
    func didTapMessageBottomLabel(in cell: MessageCollectionViewCell) {
    }
    
    private func tapOnMessage(_ message:ChatMessage) {
        if message.sender.id == currentUser()!.uid! {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if messageIsPhoto(message) {
                alert.addAction(UIAlertAction(title: "show photo", style: .default, handler: { _ in
                    self.performSegue(withIdentifier: "showPhoto", sender: message)
                }))
            }
            if messageIsLocation(message) {
                alert.addAction(UIAlertAction(title: "show map", style: .default, handler: { _ in
                    self.performSegue(withIdentifier: "showMap", sender: message)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "delete message", style: .destructive, handler: { _ in
                if let msg = Model.shared.getMessage(from: currentUser()!, date: message.sentDate) {
                    SVProgressHUD.show(withStatus: "Delete...")
                    Model.shared.deleteMessage(msg, completion: {
                        SVProgressHUD.dismiss()
                    })
                }
            }))
            alert.addAction(UIAlertAction(title: "cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            if messageIsPhoto(message) {
                self.performSegue(withIdentifier: "showPhoto", sender: message)
            }
            if messageIsLocation(message) {
                self.performSegue(withIdentifier: "showMap", sender: message)
            }
        }
    }
    
    private func messageIsPhoto(_ message:ChatMessage) -> Bool {
        switch message.kind {
        case .photo(_):
            return true
        default:
            return false
        }
    }
    
    private func messageIsLocation(_ message:ChatMessage) -> Bool {
        switch message.kind {
        case .location(_):
            return true
        default:
            return false
        }
    }
}

// MARK: - MessageInputBarDelegate

extension ChatController: MessageInputBarDelegate {
    
    func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {

        // Each NSTextAttachment that contains an image will count as one empty character in the text: String
        
        for component in inputBar.inputTextView.components {
            if let text = component as? String {
                Model.shared.sendTextMessage(text, to: opponent!.uid!)
            }
        }
        inputBar.inputTextView.text = String()
    }
}

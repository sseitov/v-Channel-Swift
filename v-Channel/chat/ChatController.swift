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
        
        let messsages = Model.shared.chatMessages(with: opponent!.uid!)
        for item in messsages {
            item.isNew = false
            messageList.append(ChatMessage(item))
        }
        Model.shared.saveContext()
        
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.checkIncomming),
                                               name: contactNotification,
                                               object: nil)
        checkIncomming()

        messagesCollectionView.scrollToBottom()
    }
    
    // MARK: - Message management

    @objc
    func checkIncomming() {
        if UIApplication.shared.applicationState == .active {
            if let call = UserDefaults.standard.object(forKey: "incommingCall") as? [String:Any] {
                if let callId = call["uid"] as? String, let from = call["from"] as? String, let user = Model.shared.getUser(from) {
                    Alert.question(title: "Incomming Call", message: "\(user.name!) call you.", okHandler: {
                        Model.shared.acceptCall(callId)
                        self.performSegue(withIdentifier: "call", sender: callId)
                    }, cancelHandler: {
                        Model.shared.hangUpCall(callId)
                    }, okTitle: "Accept", cancelTitle: "Reject")
                }
            }
        }
    }

    @objc
    func deleteMessage(_ notify:Notification) {
        if let message = notify.object as? Message {
            let chatMessage = ChatMessage(message)
            if let index = messageList.index(where: { msg in
                return msg.messageId == chatMessage.messageId
            }) {
                messagesCollectionView.performBatchUpdates({
                    messageList.remove(at: index)
                    let indexSet = IndexSet(integer: index)
                    messagesCollectionView.deleteSections(indexSet)
                }, completion: { _ in
                    self.reloadInputViews()
                })
            }
        }
    }

    @objc
    func newMessage(_ notify:Notification) {
        if let message = notify.object as? Message {
            message.isNew = false
            Model.shared.saveContext()
            let chatMessage = ChatMessage(message)
            messagesCollectionView.performBatchUpdates({
                messageList.append(chatMessage)
                messagesCollectionView.insertSections([messageList.count - 1])
            }, completion: { _ in
                self.reloadInputViews()
                self.messagesCollectionView.scrollToBottom()
            })
        }
    }

    private func pressAccessoryButton() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let selections:[AlertSelection] = [
            AlertSelection(name: "Photo from Camera Roll", handler: {
                self.becomeFirstResponder()
                let imagePicker = UIImagePickerController()
                imagePicker.allowsEditing = false
                imagePicker.sourceType = .photoLibrary
                imagePicker.delegate = self
                imagePicker.modalPresentationStyle = .formSheet
                imagePicker.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : MainColor, NSAttributedStringKey.font : UIFont.condensedFont(15)]
                imagePicker.navigationBar.tintColor = MainColor
                self.present(imagePicker, animated: true, completion: nil)
            }),
            AlertSelection(name: "Create photo use Camera", handler: {
                self.becomeFirstResponder()
                let imagePicker = UIImagePickerController()
                imagePicker.allowsEditing = false
                imagePicker.sourceType = .camera
                imagePicker.delegate = self
                imagePicker.modalPresentationStyle = .formSheet
                imagePicker.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : MainColor, NSAttributedStringKey.font : UIFont.condensedFont(15)]
                imagePicker.navigationBar.tintColor = MainColor
                self.present(imagePicker, animated: true, completion: nil)
            }),
            AlertSelection(name: "My current location", handler: {
                self.becomeFirstResponder()
                SVProgressHUD.show(withStatus: "Get Location...")
                LocationManager.shared.updateLocation({ location in
                    SVProgressHUD.dismiss()
                    if location != nil {
                        Model.shared.sendLocationMessage(location!.coordinate, to: self.opponent!.uid!)
                    } else {
                        Alert.message(title: "Error", message: "Can not get your location")
                    }
                })
            })]
        Alert.select(title: "Choose Data".uppercased(), handlers: selections, cancelHandler: {
            self.becomeFirstResponder()
        })
    }
    
    // MARK: - UIImagePickerController delegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: {
            if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
                SVProgressHUD.show(withStatus: "Send...")
                Model.shared.sendImageMessage(pickedImage, to: self.opponent!.uid!, result: { error in
                    SVProgressHUD.dismiss()
                    if error != nil {
                        Alert.message(title: "Error", message: error!.localizedDescription)
                    }
                })
            }
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
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
        } else if segue.identifier == "call" {
            let controller = segue.destination as! CallController
            if let call = sender as? String {
                controller.incommingCall = call
            }
            controller.user = self.opponent
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
            TextFieldContainer.deactivateAll()
            if messageIsPhoto(message) || messageIsLocation(message) {
                var selections:[AlertSelection] = []
                if messageIsPhoto(message) {
                    self.becomeFirstResponder()
                    selections.append(AlertSelection(name: "Show photo", handler: {
                        self.performSegue(withIdentifier: "showPhoto", sender: message)
                    }))
                }
                if messageIsLocation(message) {
                    self.becomeFirstResponder()
                    selections.append(AlertSelection(name: "Show map", handler: {
                        self.performSegue(withIdentifier: "showMap", sender: message)
                    }))
                }
                selections.append(AlertSelection(name: "Delete message", handler: {
                    self.becomeFirstResponder()
                    if let msg = Model.shared.getMessage(from: currentUser()!, date: message.sentDate) {
                        SVProgressHUD.show(withStatus: "Delete...")
                        Model.shared.deleteMessage(msg, completion: {
                            SVProgressHUD.dismiss()
                        })
                    }
                }))
                Alert.select(title: "Choose action".uppercased(), handlers: selections, cancelHandler:{ self.becomeFirstResponder() })
            } else {
                Alert.question(title: "Attention!", message: "Do you want to delete this message?", okHandler: {
                    self.becomeFirstResponder()
                    if let msg = Model.shared.getMessage(from: currentUser()!, date: message.sentDate) {
                        SVProgressHUD.show(withStatus: "Delete...")
                        Model.shared.deleteMessage(msg, completion: {
                            SVProgressHUD.dismiss()
                        })
                    }
                }, cancelHandler: {
                    self.becomeFirstResponder()
                })
            }
        } else {
            if messageIsPhoto(message) {
                TextFieldContainer.deactivateAll()
                self.performSegue(withIdentifier: "showPhoto", sender: message)
            }
            if messageIsLocation(message) {
                TextFieldContainer.deactivateAll()
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

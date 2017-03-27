//
//  ContactCell.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 22.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

class ContactCell: UITableViewCell {
    
    @IBOutlet weak var contactView: UIImageView!
    @IBOutlet weak var background: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var contactLabel: UILabel!
    @IBOutlet weak var statusView: UIImageView!
    
    fileprivate var user:User?
    var contact:Contact? {
        didSet {
            if currentUser() == nil || contact == nil {
                return
            }
            if contact!.initiator! == currentUser()!.uid! {
                user = Model.shared.getUser(contact!.requester!)
            } else {
                user = Model.shared.getUser(contact!.initiator!)
            }
            if user!.name != nil {
                nameLabel.text = user!.name
            } else {
                nameLabel.text = user!.email
            }
            
            contactView.image = user!.getImage()
            contactLabel.font = UIFont.condensedFont()
            if let call = UserDefaults.standard.object(forKey: "incommingCall") as? [String:Any], let from = call["from"] as? String, let incomming = Model.shared.contactWithUser(from), incomming == contact! {
                
                var anim:[UIImage] = []
                for i in 0..<24 {
                    anim.append(UIImage(named: "ring_frame_\(i).gif")!)
                }
                statusView.animationImages = anim
                statusView.animationDuration = 2
                statusView.animationRepeatCount = 0
                statusView.startAnimating()
                statusView.isHidden = false
            } else {
                switch contact!.getContactStatus() {
                case .requested:
                    if contact!.requester! == currentUser()!.uid {
                        contactLabel.text = "REQUEST FOR CHAT"
                        let anim:[UIImage] = [UIImage(named: "alert")!,
                                              UIImage.imageWithColor(UIColor.clear, size: statusView.frame.size)]
                        statusView.animationImages = anim
                        statusView.animationDuration = 1
                        statusView.animationRepeatCount = 0
                        statusView.startAnimating()
                    } else {
                        contactLabel.text = "WAITING..."
                        var anim:[UIImage] = []
                        for i in 0..<24 {
                            anim.append(UIImage(named: "frame_\(i).gif")!)
                        }
                        statusView.animationImages = anim
                        statusView.animationDuration = 2
                        statusView.animationRepeatCount = 0
                        statusView.startAnimating()
                    }
                    statusView.isHidden = false
                case .rejected:
                    contactLabel.text = "REJECTED"
                    statusView.stopAnimating()
                    statusView.image = UIImage(named: "stop")
                    statusView.isHidden = false
                case .approved:
                    contactLabel.font = UIFont.mainFont()
                    if let message = Model.shared.lastMessageInChat(user!.uid!) {
                        contactLabel.text = message.text
                    } else {
                        contactLabel.text = ""
                    }
                    let unread = Model.shared.unreadCountInChat(user!.uid!)
                    if unread > 0 {
                        let anim:[UIImage] = [UIImage(named: "alert")!,
                                              UIImage.imageWithColor(UIColor.clear, size: statusView.frame.size)]
                        statusView.animationImages = anim
                        statusView.animationDuration = 1
                        statusView.animationRepeatCount = 0
                        statusView.startAnimating()
                        statusView.isHidden = false
                    } else {
                        statusView.stopAnimating()
                        statusView.isHidden = true
                    }
                }
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contactView.setupCircle()
        background.setupBorder(UIColor.clear, radius: 5)
    }
    
}

//
//  ContactCell.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 22.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

class ContactCell: UITableViewCell {
    
    var user:User? {
        didSet {
            contactImage.image = UIImage(data: user!.avatar as! Data)?.inCircle()
            contactName.text = user!.name
        }
    }
    
    var incomming:Bool? {
        didSet {
            if incomming != nil && incomming! {
                var anim:[UIImage] = []
                for i in 0..<24 {
                    anim.append(UIImage(named: "ring_frame_\(i).gif")!)
                }
                callStatus.animationImages = anim
                callStatus.animationDuration = 2
                callStatus.animationRepeatCount = 0
                callStatus.startAnimating()
                callStatus.isHidden = false
            } else if contact!.contactStatus() == .approved {
                callStatus.stopAnimating()
                callStatus.isHidden = true
            }
        }
    }
    
    var contact:Contact? {
        didSet {
            if contact != nil {
                if contact!.contactStatus() == .requested {
                    if contact!.initiator! == currentUser()!.uid! {
                        var anim:[UIImage] = []
                        for i in 0..<24 {
                            anim.append(UIImage(named: "frame_\(i).gif")!)
                        }
                        callStatus.animationImages = anim
                        callStatus.animationDuration = 2
                        callStatus.animationRepeatCount = 0
                        callStatus.startAnimating()
                    } else {
                        let anim:[UIImage] = [UIImage(named: "alert")!,
                                              UIImage.imageWithColor(UIColor.clear, size: callStatus.frame.size)]
                        callStatus.animationImages = anim
                        callStatus.animationDuration = 1
                        callStatus.animationRepeatCount = 0
                        callStatus.startAnimating()
                    }
                    callStatus.isHidden = false
                    contactName.font = UIFont.thinFont()
                    contactName.textColor = UIColor.black
                } else if contact!.contactStatus() == .rejected {
                    callStatus.stopAnimating()
                    callStatus.image = UIImage(named: "stop")
                    callStatus.isHidden = false
                    contactName.font = UIFont.condensedFont()
                    contactName.textColor = UIColor.errorColor()
                } else {
                    callStatus.stopAnimating()
                    callStatus.isHidden = true
                    contactName.font = UIFont.mainFont()
                    contactName.textColor = UIColor.black
                }
            }
        }
    }
    
    @IBOutlet weak var contactImage: UIImageView!
    @IBOutlet weak var contactName: UILabel!
    @IBOutlet weak var callStatus: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        callStatus.isHidden = true
    }
}

//
//  AppUser+CoreDataClass.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 23.06.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData
import SDWebImage

enum SocialType:Int16 {
    case email = 0
    case facebook = 1
    case google = 2
}


public class AppUser: NSManagedObject {
  
    lazy var socialType: SocialType = {
        if let val = SocialType(rawValue: self.type) {
            return val
        } else {
            return .email
        }
    }()
    
    func socialTypeName() -> String {
        switch socialType {
        case .email:
            return "Email"
        case .facebook:
            return "Facebook"
        case .google:
            return "Google +"
        }
    }
    
    func getData() -> [String:Any] {
        var profile:[String : Any] = ["socialType" : Int(type)]
        if email != nil {
            profile["email"] = email!
        }
        if name != nil {
            profile["name"] = name!
        }
        if avatarURL != nil {
            profile["avatarURL"] = avatarURL!
        }
        if facebookID != nil {
            profile["facebookID"] = facebookID!
        }
        return profile
    }
    
    func setData(_ profile:[String : Any], completion: @escaping() -> ()) {
        if let typeVal = profile["socialType"] as? Int {
            type = Int16(typeVal)
        } else {
            type = 0
        }
        facebookID = profile["facebookID"] as? String
        email = profile["email"] as? String
        name = profile["name"] as? String
        
        avatarURL = profile["avatarURL"] as? String
        
        if avatarURL != nil {
            if type > 0, let url = URL(string: avatarURL!) {
                SDWebImageDownloader.shared().downloadImage(with: url, options: [], progress: nil, completed: { _, data, error, _ in
                    self.avatar = data as NSData?
                    Model.shared.saveContext()
                    completion()
                })
            } else {
                let ref = Model.shared.storageRef.child(avatarURL!)
                ref.getData(maxSize: INT64_MAX, completion: { data, error in
                    self.avatar = data as NSData?
                    Model.shared.saveContext()
                    completion()
                })
            }
        } else {
            avatar = nil
            completion()
        }
    }
    
    func containsContact(contact:Contact) -> Bool {
        if let contacts = self.contacts?.allObjects as? [Contact] {
            return contacts.contains(contact)
        } else {
            return false
        }
    }
    
    func getImage() -> UIImage {
        if avatar != nil {
            return UIImage(data: avatar! as Data)!
        } else {
            return UIImage.imageWithColor(
                ColorUtility.md5color(email!),
                size: CGSize(width: 100, height: 100)).addImage(UIImage(named: "question")!)
        }
    }

}

//
//  User+CoreDataClass.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData


public class User: NSManagedObject {
    
    func contactStatus(_ user:User) -> ContactStatus {
        if let contacts = self.contacts?.allObjects as? [Contact] {
            for contact in contacts {
                if contact.initiator! == self.uid! && contact.requester! == user.uid! {
                    return ContactStatus(rawValue: contact.status)!
                } else if contact.initiator! == user.uid! && contact.requester! == self.uid! {
                    return ContactStatus(rawValue: contact.status)!
                }
            }
            return .none
        } else {
            return .none
        }
    }
    
    func containsContact(contact:Contact) -> Bool {
        if let contacts = self.contacts?.allObjects as? [Contact] {
            return contacts.contains(contact)
        } else {
            return false
        }
    }
}

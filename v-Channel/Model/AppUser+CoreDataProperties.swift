//
//  AppUser+CoreDataProperties.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 18.11.2017.
//  Copyright © 2017 V-Channel. All rights reserved.
//
//

import Foundation
import CoreData


extension AppUser {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppUser> {
        return NSFetchRequest<AppUser>(entityName: "AppUser")
    }

    @NSManaged public var avatar: NSData?
    @NSManaged public var avatarURL: String?
    @NSManaged public var email: String?
    @NSManaged public var facebookID: String?
    @NSManaged public var name: String?
    @NSManaged public var type: Int16
    @NSManaged public var uid: String?
    @NSManaged public var contacts: NSSet?

}

// MARK: Generated accessors for contacts
extension AppUser {

    @objc(addContactsObject:)
    @NSManaged public func addToContacts(_ value: Contact)

    @objc(removeContactsObject:)
    @NSManaged public func removeFromContacts(_ value: Contact)

    @objc(addContacts:)
    @NSManaged public func addToContacts(_ values: NSSet)

    @objc(removeContacts:)
    @NSManaged public func removeFromContacts(_ values: NSSet)

}

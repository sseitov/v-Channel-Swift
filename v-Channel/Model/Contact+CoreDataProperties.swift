//
//  Contact+CoreDataProperties.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData


extension Contact {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Contact> {
        return NSFetchRequest<Contact>(entityName: "Contact");
    }

    @NSManaged public var initiator: String?
    @NSManaged public var requester: String?
    @NSManaged public var status: Int16
    @NSManaged public var uid: String?
    @NSManaged public var owner: User?

}

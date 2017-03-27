//
//  Message+CoreDataProperties.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 27.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData


extension Message {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Message> {
        return NSFetchRequest<Message>(entityName: "Message");
    }

    @NSManaged public var uid: String?
    @NSManaged public var text: String?
    @NSManaged public var to: String?
    @NSManaged public var longitude: Double
    @NSManaged public var latitude: Double
    @NSManaged public var isNew: Bool
    @NSManaged public var date: NSDate?
    @NSManaged public var from: String?
    @NSManaged public var imageData: NSData?
    @NSManaged public var imageURL: String?

}

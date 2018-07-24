//
//  Message+CoreDataClass.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 27.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData
import CoreLocation
import MessageKit

public class Message: NSManagedObject {
    
    func setData(_ data:[String:Any], new:Bool, completion:@escaping () -> ()) {
        from = data["from"] as? String
        to = data["to"] as? String
        text = data["text"] as? String
        imageURL = data["image"] as? String
        isNew = new
        if let dateVal = data["date"] as? String {
            date = Model.shared.dateFormatter.date(from: dateVal) as NSDate?
        } else {
            date = nil
        }
        if let lat = data["latitude"] as? Double, let lon = data["longitude"] as? Double {
            latitude = lat
            longitude = lon
        } else {
            latitude = 0
            longitude = 0
        }
        
        if imageURL != nil {
            let ref = Model.shared.storageRef.child(imageURL!)
            ref.getData(maxSize: INT64_MAX, completion: { data, error in
                self.imageData = data as NSData?
                Model.shared.saveContext()
                completion()
            })
        } else {
            Model.shared.saveContext()
            completion()
        }
    }

    func location() -> CLLocationCoordinate2D? {
        if latitude != 0 && longitude != 0 {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            return nil
        }
    }
}

struct ChatImageItem: MediaItem {
    
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
    
    init(image: UIImage) {
        self.image = image
        self.size = CGSize(width: 240, height: 240)
        self.placeholderImage = UIImage()
    }
    
}

struct ChatLocationItem: LocationItem {
    
    var location: CLLocation
    var size: CGSize
    
    init(location: CLLocation) {
        self.location = location
        self.size = CGSize(width: 240, height: 240)
    }
    
}

struct ChatMessage: MessageType {
    
    var messageId: String
    var sender: Sender
    var sentDate: Date
    var kind: MessageKind

    init(_ message:Message) {
        messageId = message.uid!
        if message.from! == currentUser()!.uid! {
            sender = Sender(id: message.from!, displayName: currentUser()!.name!)
        } else {
            if let user = Model.shared.getUser(message.from!) {
                sender = Sender(id: message.from!, displayName: user.name!)
            } else {
                sender = Sender(id: message.from!, displayName: "unknown")
            }
        }
        sentDate = (message.date as Date?)!
        if let data = message.imageData as Data?, let image = UIImage(data: data) {
            let mediaItem = ChatImageItem(image: image)
            kind = .photo(mediaItem)
        } else if let location = message.location() {
            let locationItem = ChatLocationItem(location: CLLocation(latitude: location.latitude, longitude: location.longitude))
            kind = .location(locationItem)
        } else {
            if message.text != nil {
                kind = .text(message.text!)
            } else {
                kind = .text("")
            }
        }
    }
}

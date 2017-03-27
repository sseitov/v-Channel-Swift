//
//  Message+CoreDataClass.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 27.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData

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
            ref.data(withMaxSize: INT64_MAX, completion: { data, error in
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

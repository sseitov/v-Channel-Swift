//
//  Contact+CoreDataClass.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import CoreData

enum ContactStatus:Int16 {
    case none           = 0
    case requested      = 1
    case approved       = 2
    case rejected       = 3
}

public class Contact: NSManagedObject {
    
    func contactStatus() -> ContactStatus {
        switch status {
        case 1:
            return .requested
        case 2:
            return .approved
        case 3:
            return .rejected
        default:
            return .none
        }
    }
    
    func getData() -> [String:Any] {
        Model.shared.saveContext()
        let data:[String:Any] = ["uid" : uid!, "initiator" : initiator!, "requester" : requester!, "status" : Int(status)]
        return data
    }
    
    func setData(_ data:[String:Any]) {
        initiator = data["initiator"] as? String
        requester = data["requester"] as? String
        if let st = data["status"] as? Int {
            status = Int16(st)
        }
        Model.shared.saveContext()
    }
    
}
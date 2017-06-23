//
//  CLLocationExtension.swift
//
//  Created by Сергей Сейтов on 22.05.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import CoreLocation

extension CLLocation {
    
    class func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let to = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return from.distance(from: to)
    }
}

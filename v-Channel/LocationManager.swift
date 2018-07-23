//
//  LocationManager.swift
//  ispingle
//
//  Created by Сергей Сейтов on 15.03.17.
//  Copyright © 2017 ispingle. All rights reserved.
//

import UIKit
import CoreLocation

class LocationManager: NSObject {
    
    static let shared = LocationManager()
    
    let locationManager = CLLocationManager()
    let locationCondition = NSCondition()
    
    var currentLocation:CLLocation?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        locationManager.headingFilter = 5.0
    }

    func updateLocation(_ location: @escaping(CLLocation?) -> ()) {
        if CLLocationManager.locationServicesEnabled() {
            currentLocation = nil
            if CLLocationManager.authorizationStatus() != .authorizedWhenInUse {
                self.locationManager.requestWhenInUseAuthorization()
            } else {
                self.locationManager.startUpdatingLocation()
            }
            DispatchQueue.global().async {
                self.locationCondition.lock()
                self.locationCondition.wait()
                self.locationCondition.unlock()
                DispatchQueue.main.async {
                    location(self.currentLocation)
                }
            }
        } else {
            location(nil)
        }
    }
    
    func stop() {
    }
}

extension LocationManager : CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if CLLocationManager.authorizationStatus() != .authorizedWhenInUse {
            self.locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            locationManager.stopUpdatingLocation()
            self.locationCondition.lock()
            self.currentLocation = location
            self.locationCondition.signal()
            self.locationCondition.unlock()
        }
    }
}

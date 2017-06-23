//
//  MKMapRectExtension.swift
//
//  Created by Сергей Сейтов on 22.05.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import MapKit

extension MKMapRect {
    init(coordinates: [CLLocationCoordinate2D]) {
        self = coordinates.map({ MKMapPointForCoordinate($0) }).map({ MKMapRect(origin: $0, size: MKMapSize(width: 0, height: 0)) }).reduce(MKMapRectNull, MKMapRectUnion)
    }
}

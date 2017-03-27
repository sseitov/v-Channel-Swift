//
//  LocationMediaItem.swift
//  iNear
//
//  Created by Сергей Сейтов on 04.03.17.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit

class LocationMediaItem : JSQLocationMediaItem {
    
    var cashedImageView:UIImageView?
    var messageLocation:CLLocationCoordinate2D?
    
    override func setLocation(_ location: CLLocation!, withCompletionHandler completion: JSQLocationMediaItemCompletionBlock!) {
        if location != nil {
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 120))
            locationShapshot(size: imageView.frame.size, center: location.coordinate, result: { image in
                imageView.image = image
                JSQMessagesMediaViewBubbleImageMasker.applyBubbleImageMask(toMediaView: imageView,
                                                                           isOutgoing: self.appliesMediaViewMaskAsOutgoing)
                self.cashedImageView = imageView
                completion()
            })
        }
    }
    
    override func mediaView() -> UIView! {
        return cashedImageView
    }
    
    override func mediaViewDisplaySize() -> CGSize {
        return CGSize(width: 200, height: 120)
    }
    
    private func locationShapshot(size:CGSize, center:CLLocationCoordinate2D, result:@escaping (UIImage?) -> ()) {

        let marker = currentUser()!.getImage().withSize(CGSize(width: 30, height: 30)).inCircle()
        
        let options = MKMapSnapshotOptions()
        options.mapType = .standard
        options.scale = 1.0
        options.size = size
        let span = MKCoordinateSpanMake(0.1, 0.1)
        options.region = MKCoordinateRegionMake(center, span)
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(with: DispatchQueue.main, completionHandler: { snap, error in
            if error != nil {
                print(error!)
                result(nil)
                return
            }
            if let image = snap?.image {
                UIGraphicsBeginImageContext(image.size)
                image.draw(at: CGPoint())
                
                var startPt = snap!.point(for: center)
                startPt = CGPoint(x: startPt.x - marker.size.width/2.0, y: startPt.y - marker.size.height/2.0)
                marker.draw(at: startPt)
                
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                result(image)
            } else {
                result(nil)
            }
        })
    }

}

//
//  UIImageExtensions.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

extension UIImage {
    class func imageWithColor(_ color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(size)
        color.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    func withSize(_ newSize:CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        let aspect = self.size.width / self.size.height
        var width = newSize.width
        var height = newSize.height
        if aspect > 1 { // landscape
            width = aspect*height
        } else if aspect < 1 {
            height = width / aspect
        }
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func inCircle() -> UIImage {
        let newImage = self.copy() as! UIImage
        let cornerRadius = self.size.height/2
        UIGraphicsBeginImageContextWithOptions(self.size, false, 1.0)
        let bounds = CGRect(origin: CGPoint(), size: self.size)
        UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).addClip()
        newImage.draw(in: bounds)
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage!
    }
    
    func addImage(_ image:UIImage) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, 1.0)
        let bounds = CGRect(origin: CGPoint(), size: self.size)
        let pt = CGPoint(x: (self.size.width - image.size.width)/2.0, y: (self.size.height - image.size.height)/2.0)
        let imageBounds = CGRect(origin: pt, size: image.size)
        self.draw(in: bounds)
        image.draw(in: imageBounds)
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return finalImage!
    }

}

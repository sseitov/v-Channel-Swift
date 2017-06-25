//
//  UIImageExtension.swift
//
//  Created by Сергей Сейтов on 22.05.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

func compositeTwoImages(left: UIImage, right: UIImage, newSize: CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
    right.draw(in: CGRect(x: newSize.width - right.size.width, y: 0, width: right.size.width, height: right.size.height))
    left.draw(in: CGRect(x: 0, y: 0, width: left.size.width, height: left.size.height))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage
}

func imageIntoImage(inner: UIImage, outer: UIImage) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(outer.size, false, 0.0)
    outer.draw(in: CGRect(x: 0, y: 0, width: outer.size.width, height: outer.size.height))
    let offsetX = (outer.size.width - inner.size.width) / 2
    let offsetY = (outer.size.height - inner.size.height) / 2
    inner.draw(at: CGPoint(x: offsetX, y: offsetY))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage
}

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
    
    func withAlpha(_ alpha: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: CGPoint.zero, blendMode: .normal, alpha: alpha)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func partWithFrame(_ frame:CGRect) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(frame.size, false, 0.0);
        let x = (self.size.width - frame.size.width)/2
        let y = (self.size.height - frame.size.height)/2
        self.draw(in: CGRect(x: -x, y: -y, width: self.size.width, height: self.size.height))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    class func imageFromLayer(layer: CALayer) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(layer.bounds.size, layer.isOpaque, 0.0)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
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

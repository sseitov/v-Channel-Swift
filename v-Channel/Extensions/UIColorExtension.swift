//
//  UIColorExtension.swift
//
//  Created by Сергей Сейтов on 22.05.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

let MainColor = UIColor.color(50, 150, 100, 1)
let ErrorColor = UIColor.color(240, 90, 80, 1)
let CancelColor = UIColor.color(128, 128, 128, 1)

extension UIColor {
    class func color(_ r: Float, _ g: Float, _ b: Float, _ a: Float) -> UIColor {
        return UIColor(red: CGFloat(r/255.0), green: CGFloat(g/255.0), blue: CGFloat(b/255.0), alpha: CGFloat(a))
    }
    
    class func color(_ rgb:UInt32) -> UIColor {
        let red = CGFloat((rgb & 0xFF0000) >> 16)
        let green = CGFloat((rgb & 0xFF00) >> 8)
        let blue = CGFloat(rgb & 0xFF)
        return UIColor(red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: 1.0)
    }
    
    func imageFromColor(_ size:CGSize, cornerRadius:CGFloat) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(self.cgColor);
        context?.fill(rect);
        
        var image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        UIGraphicsBeginImageContext(size)
        let path = UIBezierPath(roundedRect:rect, cornerRadius: cornerRadius)
        path.addClip()
        image?.draw(in: rect)
        image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
}

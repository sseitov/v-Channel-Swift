//
//  NSStringExtension.swift
//
//  Created by Сергей Сейтов on 12.06.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

extension NSString {
    
    func draw(_ font:UIFont, color:UIColor, rect:CGRect, alignment:NSTextAlignment = .center) {
        let textStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        textStyle.alignment = alignment
        
        let textFontAttributes = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: color,
            NSAttributedStringKey.paragraphStyle: textStyle
        ]
        
        let size = self.size(withAttributes: textFontAttributes)
        let r = CGRect(x: rect.origin.x,
                       y: rect.origin.y + (rect.size.height - size.height)/2.0,
                       width: rect.size.width,
                       height: size.height)
        
        self.draw(in: r, withAttributes: textFontAttributes)
    }
    
}

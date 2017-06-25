//
//  UIFontExtension.swift
//
//  Created by Сергей Сейтов on 22.05.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

func printFontNames() {
    for family:String in UIFont.familyNames {
        print("\(family)")
        for names:String in UIFont.fontNames(forFamilyName: family) {
            print("== \(names)")
        }
    }
}

extension UIFont {
    
    class func mainFont(_ size:CGFloat = 17) -> UIFont {
        return UIFont(name: "HelveticaNeue", size: size)!
    }
    
    class func thinFont(_ size:CGFloat = 17) -> UIFont {
        return UIFont(name: "HelveticaNeue-Thin", size: size)!
    }
    
    class func condensedFont(_ size:CGFloat = 17) -> UIFont {
        return UIFont(name: "HelveticaNeue-CondensedBold", size: size)!
    }
    
    class func commentsFont() -> UIFont {
        return mainFont(15)
    }
}

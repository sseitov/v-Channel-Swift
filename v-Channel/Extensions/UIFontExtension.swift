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
        return UIFont(name: "SFUIDisplay-Regular", size: size) ?? UIFont.systemFont(ofSize: 17)
    }
    
    class func mediumFont(_ size:CGFloat = 17) -> UIFont {
        return UIFont(name: "SFUIDisplay-Medium", size: size) ?? UIFont.systemFont(ofSize: 17)
    }
    
    class func lightFont(_ size:CGFloat = 17) -> UIFont {
        return UIFont(name: "SFUIDisplay-Light", size: size) ?? UIFont.systemFont(ofSize: 17)
    }
    
    class func thinFont(_ size:CGFloat = 17) -> UIFont {
        return UIFont(name: "SFUIDisplay-Thin", size: size) ?? UIFont.systemFont(ofSize: 17)
    }
    
    class func condensedFont(_ size:CGFloat = 17) -> UIFont {
        return UIFont(name: "SFUIDisplay-Semibold", size: size) ?? UIFont.systemFont(ofSize: 17)
    }
}

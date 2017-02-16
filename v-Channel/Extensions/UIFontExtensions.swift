//
//  UIFontExtensions.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

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
}

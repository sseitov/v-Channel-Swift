//
//  TextFieldContainer.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

protocol TextFieldContainerDelegate {
    func textDone(_ sender:TextFieldContainer, text:String?)
    func textChange(_ sender:TextFieldContainer, text:String?) -> Bool
}

class TextFieldContainer: UIView, UITextFieldDelegate {

    var delegate:TextFieldContainerDelegate?
    
    var nonActiveColor:UIColor = UIColor.groupTableViewBackground
    var activeColor:UIColor = UIColor.white
    var placeholderColor = UIColor.gray
    
    var textType:UIKeyboardType! {
        didSet {
            textField.keyboardType = textType
        }
    }
    var secure:Bool = false {
        didSet {
            textField.isSecureTextEntry = secure
        }
    }
    var returnType:UIReturnKeyType = .default {
        didSet {
            textField.returnKeyType = returnType
        }
    }
    var autocapitalizationType:UITextAutocapitalizationType = .none {
        didSet {
            textField.autocapitalizationType = autocapitalizationType
        }
    }
    
    var placeholder: String = "" {
        didSet {
            textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [NSForegroundColorAttributeName : placeholderColor])
        }
    }
    
    var textFont: UIFont? = UIFont(name: "HelveticaNeue-CondensedBold", size: 15) {
        didSet {
            textField.font = textFont
        }
    }
    
    var textField:UITextField!
    
    class func deactivateAll() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textField = UITextField(frame: self.bounds.insetBy(dx: 10, dy: 3))
        textField.textAlignment = .center
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.delegate = self
        
        backgroundColor = nonActiveColor
        setupBorder(UIColor.mainColor(), radius: 5)
        textField.font = textFont
        textField.textColor = UIColor.mainColor()
        
        self.addSubview(textField)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        textField.frame = self.bounds.insetBy(dx: 10, dy: 3)
    }
    
    func activate(_ active:Bool) {
        backgroundColor = text().isEmpty ? nonActiveColor : activeColor
        if active {
            textField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
    }
    
    func text() -> String {
        return textField.text == nil ? "" : textField.text!
    }
    
    func setText(_ text:String) {
        textField.text = text
        backgroundColor = text.isEmpty ? nonActiveColor : activeColor
    }
    
    func clear() {
        textField.text = ""
        backgroundColor = nonActiveColor
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText:String? = textField.text != nil ? (textField.text! as NSString).replacingCharacters(in: range, with: string) : nil
        if newText == nil || newText!.isEmpty {
            backgroundColor = nonActiveColor
        } else {
            backgroundColor = activeColor
        }
        if string == "\n" {
            textField.resignFirstResponder()
            delegate?.textDone(self, text: textField.text)
            return false
        } else {
            if delegate != nil {
                return delegate!.textChange(self, text: newText)
            } else {
                return true
            }
        }
    }

}

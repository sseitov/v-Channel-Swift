//
//  EmailInput.swift
//  SimpleVOIP
//
//  Created by Сергей Сейтов on 04.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

typealias CompletionTextBlock = (String) -> Void

class EmailInput: LGAlertView, TextFieldContainerDelegate {

    @IBOutlet weak var inputField: TextFieldContainer!
    var handler:CompletionTextBlock?
    
    class func getEmail(cancelHandler:CompletionBlock?, acceptHandler:CompletionTextBlock?) -> EmailInput? {
        if let textInput = Bundle.main.loadNibNamed("EmailInput", owner: nil, options: nil)?.first as? EmailInput {
            textInput.inputField.delegate = textInput
            textInput.inputField.placeholder = "input email"
            textInput.inputField.textType = .emailAddress
            textInput.cancelButtonBlock = { alert in
                cancelHandler!()
            }
            textInput.otherButtonBlock = { alert in
                if textInput.inputField.text().isEmail() {
                    textInput.dismiss()
                    acceptHandler!(textInput.inputField.text())
                } else {
                    textInput.showErrorMessage("Email should have xxxx@domain.prefix format.", animated: true)
                }
            }
            textInput.handler = acceptHandler
            
            UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
            NotificationCenter.default.addObserver(textInput, selector: #selector(LGAlertView.keyboardWillChange(_:)), name: Notification.Name.UIKeyboardWillChangeFrame, object: nil)
            
            return textInput
        } else {
            return nil
        }
    }
    
    func textDone(_ sender:TextFieldContainer, text:String?) {
        if !sender.text().isEmail() {
            showErrorMessage("Email should have xxxx@domain.prefix format.", animated: true)
            sender.activate(true)
        } else {
            dismiss()
            handler!(sender.text())
        }
    }
    
    func textChange(_ sender:TextFieldContainer, text:String?) -> Bool {
        return true
    }
    
    override func show() {
        super.show()
        inputField.activate(true)
    }
    
    func showInView(_ view:UIView) {
        superView = view
        show()
        inputField.activate(true)
    }

}

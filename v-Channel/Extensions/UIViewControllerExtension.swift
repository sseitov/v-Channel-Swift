//
//  UIViewControllerExtension.swift
//
//  Created by Сергей Сейтов on 22.05.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

enum MessageType {
    case error, success, information
}

class TitleView : UILabel {
    var prompt:UILabel?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if prompt != nil {
            prompt!.frame = CGRect(x: 0, y: -20, width: Int(frame.size.width), height: 20)
        }
    }
}

extension UIViewController {
    
    func setupTitle(_ text:String, promptText:String? = nil) {
        let label = TitleView(frame: CGRect(x: 0, y: 0, width: 200, height: 44))
        label.textAlignment = .center
        label.font = UIFont.condensedFont(17)
        label.text = text.uppercased()
        label.textColor = UIColor.white
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        if promptText != nil {
            navigationItem.prompt = ""
            label.clipsToBounds = false
            label.prompt = UILabel(frame: CGRect(x: 0, y: -20, width: label.frame.size.width, height: 20))
            label.prompt!.textAlignment = .center
            label.prompt!.font = UIFont.condensedFont(15)
            label.prompt!.textColor = UIColor.white
            label.prompt!.text = promptText!
            label.addSubview(label.prompt!)
        }
        navigationItem.titleView = label
    }
    
    func setupBackButton() {
        navigationItem.leftBarButtonItem?.target = self
        navigationItem.leftBarButtonItem?.action = #selector(UIViewController.goBack)
    }
    
    @objc func goBack() {
        _ = self.navigationController!.popViewController(animated: true)
    }
    
    // MARK: - alerts
    
    func showMessage(_ message:String, messageType:MessageType, messageHandler: (() -> ())? = nil) {
        
        let alert = LGAlertView.decoratedAlert(
            withTitle: Bundle.main.infoDictionary?["CFBundleName"] as? String,
            message: message,
            cancelButtonTitle: "OK",
            cancelButtonBlock: { alert in
                if messageHandler != nil {
                    messageHandler!()
                }
        })
        if messageType == .error {
            alert!.titleLabel.textColor = ErrorColor
            alert!.okButton.backgroundColor = ErrorColor
        } else {
            alert!.titleLabel.textColor = MainColor
            alert!.okButton.backgroundColor = MainColor
        }
        alert?.show()
    }
    
    func yesNoQuestion(_ question:String, acceptLabel:String, cancelLabel:String, acceptHandler:@escaping () -> (), cancelHandler: (() -> ())? = nil) {
        
        let alert = LGAlertView.alert(
            withTitle: Bundle.main.infoDictionary?["CFBundleName"] as? String,
            message: question,
            cancelButtonTitle: cancelLabel,
            otherButtonTitle: acceptLabel,
            cancelButtonBlock: { alert in
                if cancelHandler != nil {
                    cancelHandler!()
                }
        },
            otherButtonBlock: { alert in
                alert?.dismiss()
                acceptHandler()
        })
        alert?.titleLabel.textColor = MainColor
        alert?.cancelButton.backgroundColor = CancelColor
        alert?.otherButton.backgroundColor = MainColor
        alert?.show()
    }

    func askText(_ question:String, text:String? = nil, textType:UIKeyboardType, acceptLabel:String, cancelLabel:String, acceptHandler:@escaping (String?) -> (), cancelHandler: (() -> ())? = nil) {
        
        let alert = LGAlertView.alert(
            withTitle: Bundle.main.infoDictionary?["CFBundleName"] as? String,
            message: question,
            cancelButtonTitle: cancelLabel,
            otherButtonTitle: acceptLabel,
            cancelButtonBlock: { alert in
                if cancelHandler != nil {
                    cancelHandler!()
                }
        },
            textFieldBlock: { alert in
                alert?.dismiss()
                acceptHandler(alert?.textField.text)
        })
        if textType == .default {
            alert?.textField.autocapitalizationType = .words
        }
        alert?.textField.text = text
        alert?.textField.returnKeyType = .done
        alert?.textField.textAlignment = .center
        alert?.textField.keyboardType = textType
        alert?.titleLabel.textColor = MainColor
        alert?.cancelButton.backgroundColor = CancelColor
        alert?.otherButton.backgroundColor = MainColor
        alert?.show()
    }
}

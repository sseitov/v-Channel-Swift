//
//  Alerts.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 03.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

typealias CompletionBlock = () -> Void
typealias CompletionTextBlock = (String?) -> Void

struct AlertSelection {
    let name:String
    let handler:CompletionBlock
}

class Alert: UIViewController {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleView: UILabel!
    @IBOutlet weak var messageView: UITextView!
    
    @IBOutlet weak var firstButton: UIButton!
    @IBOutlet weak var secondButton: UIButton!
    @IBOutlet weak var thirdButton: UIButton!

    @IBOutlet weak var containerHeight: NSLayoutConstraint!
    @IBOutlet weak var messageHeight: NSLayoutConstraint!
    @IBOutlet weak var thitdButtonHeight: NSLayoutConstraint!
    
    enum AlertType {
        case oneChoice
        case twoChoices
        case threeChoices
    }
    
    private var alertType:AlertType = .oneChoice
    private var message:String = ""
    private var actions:[String] = []
    
    private var firstHandler:CompletionBlock?
    private var secondHandler:CompletionBlock?
    private var thirdHandler:CompletionBlock?
    private var cancelHandler:CompletionBlock?

    private var presenter:UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        titleView.text = self.title
        containerView.setupBorder(UIColor.clear, radius: 10)
        
        if alertType == .oneChoice {
            messageView.text = self.message
            firstButton.setTitle("OK", for: .normal)
            firstButton.setupBorder(UIColor.white, radius: 20)
        } else if alertType == .twoChoices {
            messageView.text = self.message
            firstButton.setTitle("Confirm", for: .normal)
            firstButton.setupBorder(UIColor.white, radius: 20)
            secondButton.setTitle("Discard", for: .normal)
            secondButton.setupBorder(UIColor.white, radius: 20)
        } else {
            firstButton.setTitle(actions[0], for: .normal)
            firstButton.setupBorder(UIColor.white, radius: 20)
            secondButton.setTitle(actions[1], for: .normal)
            secondButton.setupBorder(.white, radius: 20)
            if thirdHandler != nil {
                thirdButton.setTitle(actions[2], for: .normal)
                thirdButton.setupBorder(UIColor.white, radius: 20)
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        if alertType == .threeChoices {
            containerHeight.constant = thirdHandler != nil ? 270 : 210
            thitdButtonHeight.constant = thirdButton != nil ? 40 : 0
        } else {
            let textSize = messageView.font!.sizeOfString(string: message, constrainedToWidth: Double(messageView.frame.width))
            messageHeight.constant = textSize.height + 30
            let buttonsHeight:CGFloat = alertType == .oneChoice ? 80 : 140
            containerHeight.constant = 40 + messageHeight.constant + buttonsHeight
        }
    }
    
    @IBAction func pressOk(_ sender: Any) {
        dismiss(animated: true, completion: {
            self.presenter?.view.removeFromSuperview()
            if self.firstHandler != nil {
                self.firstHandler!()
            }
        })
    }
    
    @IBAction func pressOther(_ sender: Any) {
        dismiss(animated: true, completion: {
            self.presenter?.view.removeFromSuperview()
            if self.secondHandler != nil {
                self.secondHandler!()
            }
        })
    }
    
    @IBAction func pressThird(_ sender: Any) {
        dismiss(animated: true, completion: {
            self.presenter?.view.removeFromSuperview()
            if self.thirdHandler != nil {
                self.thirdHandler!()
            }
        })
    }
    
    @IBAction func pressCancel(_ sender: Any) {
        dismiss(animated: true, completion: {
            self.presenter?.view.removeFromSuperview()
            if self.cancelHandler != nil {
                self.cancelHandler!()
            }
        })
    }
 
    private func show() {
        TextFieldContainer.deactivateAll()
        
        modalTransitionStyle = .crossDissolve
        modalPresentationStyle = .overCurrentContext
        
        let mainWindow = UIApplication.shared.keyWindow
        self.presenter = UIViewController()
        self.presenter!.view.backgroundColor = UIColor.clear
        self.presenter!.view.isOpaque = false
        mainWindow?.addSubview(self.presenter!.view)
        self.presenter?.present(self, animated: true, completion: nil)
    }

    class func message(title:String, message:String, okHandler:CompletionBlock? = nil) {
        let board = UIStoryboard(name: "Alerts", bundle: nil)
        if let controller = board.instantiateViewController(withIdentifier: "Alert") as? Alert {
            controller.alertType = .oneChoice
            controller.title = title.uppercased()
            controller.message = message
            controller.firstHandler = okHandler
            controller.show()
        }
    }
    
    class func question(title:String, message:String, okHandler:CompletionBlock? = nil, cancelHandler:CompletionBlock? = nil) {
        let board = UIStoryboard(name: "Alerts", bundle: nil)
        if let controller = board.instantiateViewController(withIdentifier: "Alert") as? Alert {
            controller.alertType = .twoChoices
            controller.title = title.uppercased()
            controller.message = message
            controller.firstHandler = okHandler
            controller.secondHandler = cancelHandler
            controller.show()
        }
    }
    
    class func select(title:String, handlers:[AlertSelection], cancelHandler:CompletionBlock? = nil) {
        let board = UIStoryboard(name: "Alerts", bundle: nil)
        if let controller = board.instantiateViewController(withIdentifier: "Selection") as? Alert {
            controller.alertType = .threeChoices
            controller.title = title.uppercased()
            controller.firstHandler = handlers[0].handler
            controller.actions.append(handlers[0].name)
            controller.secondHandler = handlers[1].handler
            controller.actions.append(handlers[1].name)
            if handlers.count > 2 {
                controller.thirdHandler = handlers[2].handler
                controller.actions.append(handlers[2].name)
            }
            controller.cancelHandler = cancelHandler
            controller.show()
        }
    }
}

class TextAlert: UIViewController, TextFieldContainerDelegate {
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var inputField: DefaultTextInputContainer!
    @IBOutlet weak var messageView: UIView!
    @IBOutlet weak var messageText: UILabel!
    @IBOutlet weak var titleView: UILabel!

    enum AlertType {
        case text
        case email
    }

    private var alertType:AlertType = .text
    private var handler:CompletionTextBlock?
    private var presenter:UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        titleView.text = self.title
        
        if alertType == .email {
            inputField.textType = .emailAddress
            inputField.placeholder = "E-mail"
            inputField.returnType = .done
            inputField.delegate = self
        } else {
            inputField.textType = .asciiCapable
            inputField.returnType = .done
            inputField.autoCapitalization = .words
            inputField.delegate = self
        }
        
        containerView.setupBorder(UIColor.clear, radius: 5)
        messageView.setupBorder(ErrorColor, radius: 20)
        messageView.alpha = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        inputField.activate(true)
    }
    
    @IBAction func pressOk(_ sender: Any) {
        if alertType == .email {
            acceptEmail()
        } else {
            acceptText()
        }
    }
    
    @IBAction func pressCancel(_ sender: Any) {
        TextFieldContainer.deactivateAll()
        dismiss(animated: true, completion: {
            self.presenter?.view.removeFromSuperview()
            if self.handler != nil {
                self.handler!(nil)
            }
        })
    }

    private func show() {
        TextFieldContainer.deactivateAll()
        
        modalTransitionStyle = .crossDissolve
        modalPresentationStyle = .overCurrentContext
        
        let mainWindow = UIApplication.shared.keyWindow
        self.presenter = UIViewController()
        self.presenter!.view.backgroundColor = UIColor.clear
        self.presenter!.view.isOpaque = false
        mainWindow?.addSubview(self.presenter!.view)
        self.presenter?.present(self, animated: true, completion: nil)
    }

    private func showErrorMessage(_ msg:String) {
        messageText.text = msg
        UIView.animate(withDuration: 0.5, animations: {
            self.messageView.alpha = 1
        }, completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2000), execute: {
                UIView.animate(withDuration: 0.5, animations: {
                    self.messageView.alpha = 0
                })
            })
        })
    }
    
    private func acceptEmail() {
        if !inputField.text().isEmail() {
            showErrorMessage("Email should have xxxx@domain.prefix format.")
        } else {
            acceptText()
        }
    }
    
    private func acceptText() {
        TextFieldContainer.deactivateAll()
        dismiss(animated: true, completion: {
            self.presenter?.view.removeFromSuperview()
            if self.handler != nil {
                self.handler!(self.inputField.text())
            }
        })
    }
    
    func textDone(_ sender:TextFieldContainer, text:String?) {
        if alertType == .email {
            acceptEmail()
        } else {
            acceptText()
        }
    }
    
    func textChange(_ sender:TextFieldContainer, text:String?) -> Bool {
        return true
    }
    
    class func getEmail(_ handler:CompletionTextBlock?) {
        let board = UIStoryboard(name: "Alerts", bundle: nil)
        if let controller = board.instantiateViewController(withIdentifier: "TextAlert") as? TextAlert {
            controller.title = "ENTER NEW EMAIL"
            controller.alertType = .email
            controller.handler = handler
            controller.show()
        }
    }
    
    class func getText(title:String, handler:CompletionTextBlock?) {
        let board = UIStoryboard(name: "Alerts", bundle: nil)
        if let controller = board.instantiateViewController(withIdentifier: "TextAlert") as? TextAlert {
            controller.title = title
            controller.alertType = .text
            controller.handler = handler
            controller.show()
        }
    }

}

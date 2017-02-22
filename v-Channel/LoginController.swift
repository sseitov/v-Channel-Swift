//
//  LoginController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 22.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import SVProgressHUD
import Firebase

protocol LoginControllerDelegate {
    func didLogin()
    func didLogout()
}

class LoginController: UIViewController, TextFieldContainerDelegate {

    @IBOutlet weak var userField: TextFieldContainer!
    @IBOutlet weak var passwordField: TextFieldContainer!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signUpButton: UIButton!
    
    var delegate:LoginControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("Sign In")
        
        userField.textType = .emailAddress
        userField.placeholder = "email"
        userField.returnType = .next
        userField.delegate = self
        
        passwordField.placeholder = "password"
        passwordField.returnType = .go
        passwordField.secure = true
        passwordField.delegate = self
        
        signInButton.setupBorder(UIColor.clear, radius: 40)
        signUpButton.setupBorder(UIColor.clear, radius: 40)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tap))
        self.view.addGestureRecognizer(tap)
    }
    
    func tap() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    override func goBack() {
        dismiss(animated: true, completion: nil)
    }
    
    func textDone(_ sender:TextFieldContainer, text:String?) {
        if sender == userField {
            if userField.text().isEmail() {
                passwordField.activate(true)
            } else {
                showMessage("Email should have xxxx@domain.prefix format.", messageType: .error, messageHandler: {
                    self.userField.activate(true)
                })
            }
        } else {
            if passwordField.text().isEmpty {
                showMessage("Password field required.", messageType: .error, messageHandler: {
                    self.passwordField.activate(true)
                })
            } else if userField.text().isEmpty {
                userField.activate(true)
            } else {
                emailAuth(user: userField.text(), password: passwordField.text())
            }
        }
    }
    
    func textChange(_ sender:TextFieldContainer, text:String?) -> Bool {
        return true
    }
    
    @IBAction func login(_ sender: Any) {
        userField.activate(false)
        passwordField.activate(false)
        if !userField.text().isEmail() {
            showMessage("Email should have xxxx@domain.prefix format", messageType: .error, messageHandler: {
                self.userField.activate(true)
            })
        } else if passwordField.text().isEmpty {
            showMessage("Password field required", messageType: .error, messageHandler: {
                self.passwordField.activate(true)
            })
        } else {
            emailAuth(user: userField.text(), password: passwordField.text())
        }
    }
    
    func emailAuth(user:String, password:String) {
        SVProgressHUD.show(withStatus: "Login...")
        FIRAuth.auth()?.signIn(withEmail: user, password: password, completion: { firUser, error in
            if error != nil {
                SVProgressHUD.dismiss()
                self.showMessage((error as! NSError).localizedDescription, messageType: .error)
            } else {
                if firUser!.isEmailVerified || testUser(user) {
                    Model.shared.getEmailUser(firUser!.uid, result: { user in
                        SVProgressHUD.dismiss()
                        if user != nil {
                            self.delegate?.didLogin()
                        } else {
                            self.showMessage("Can not download profile data.", messageType: .error)
                        }
                    })
                } else {
                    SVProgressHUD.dismiss()
                    self.showMessage("You must confirm your registeration. Check your mailbox and try again.", messageType: .information)
                }
            }
        })
    }
}

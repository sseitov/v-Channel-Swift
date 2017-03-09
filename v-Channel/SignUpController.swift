//
//  SignUpController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 22.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import SVProgressHUD
import Firebase

class SignUpController: UIViewController, TextFieldContainerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    @IBOutlet weak var imageButton: UIButton!
    @IBOutlet weak var nickField: TextFieldContainer!
    @IBOutlet weak var emailField: TextFieldContainer!
    @IBOutlet weak var passwordField: TextFieldContainer!
    @IBOutlet weak var signUpButton: UIButton!
   
    var userName:String?
    var userPassword:String?
    
    private var avatar:UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("SignUp")
        setupBackButton()
        imageButton.addDashedBorder()
        
        nickField.textType = .emailAddress
        nickField.placeholder = "nickname"
        nickField.returnType = .next
        nickField.autocapitalizationType = .words
        nickField.delegate = self
        
        emailField.textType = .emailAddress
        emailField.placeholder = "email"
        emailField.returnType = .next
        emailField.delegate = self
        if userName != nil {
            emailField.setText(userName!)
        }
        
        passwordField.placeholder = "password"
        passwordField.returnType = .go
        passwordField.secure = true
        passwordField.delegate = self
        if userPassword != nil {
            passwordField.setText(userPassword!)
        }
        
        signUpButton.setupBorder(UIColor.clear, radius: 30)

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tap))
        self.view.addGestureRecognizer(tap)
    }
    
    func tap() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func textDone(_ sender:TextFieldContainer, text:String?) {
        
        if sender == nickField {
            if checkFields(sender) {
                self.emailField.activate(true)
            }
        } else if sender == emailField {
            if checkFields(sender) {
                passwordField.activate(true)
            }
        } else {
            if checkFields(nil) {
                if avatar != nil {
                    emailSignUp()
                } else {
                    showMessage("Avatar image required.", messageType: .error)
                }
            }
        }
    }
    
    func textChange(_ sender:TextFieldContainer, text:String?) -> Bool {
        return true
    }
    
    func checkFields(_ sender:TextFieldContainer?) -> Bool {
        if sender == nil || sender == nickField {
            if nickField.text().isEmpty {
                showMessage("Nickname field required.", messageType: .error, messageHandler: {
                    self.nickField.activate(true)
                })
                return false
            }
        }
        if sender == nil || sender == emailField {
            if !emailField.text().isEmail() {
                showMessage("Email should have xxxx@domain.prefix format.", messageType: .error, messageHandler: {
                    self.emailField.activate(true)
                })
                return false
            }
        }
        if sender == nil || sender == passwordField {
            if passwordField.text().isEmpty {
                showMessage("Password field required.", messageType: .error, messageHandler: {
                    self.passwordField.activate(true)
                })
                return false
            }
        }
        return true
    }
    
    @IBAction func signUp(_ sender: Any) {
        if checkFields(nil) {
            if avatar != nil {
                emailSignUp()
            } else {
                showMessage("Avatar image required.", messageType: .error)
            }
        }
    }
    
    func emailSignUp() {
        SVProgressHUD.show(withStatus: "SignUp...")
        FIRAuth.auth()?.createUser(withEmail: emailField.text(), password: passwordField.text(), completion: { firUser, error in
            if error != nil {
                SVProgressHUD.dismiss()
                self.showMessage((error as! NSError).localizedDescription, messageType: .error)
            } else {
                Model.shared.createEmailUser(firUser!,
                                             email: self.emailField.text(),
                                             nick: self.nickField.text(),
                                             image: self.avatar!, result:
                    { setError in
                        if setError == nil {
                            FIRAuth.auth()?.currentUser?.sendEmailVerification(completion: { error in
                                SVProgressHUD.dismiss()
                                if error == nil {
                                    self.showMessage("Check your mailbox now. You account will be activated after you confirm registration.", messageType: .information, messageHandler: {
                                        self.goBack()
                                    })
                                } else {
                                    self.showMessage(setError!.localizedDescription, messageType: .error)
                                }
                            })
                        } else {
                            SVProgressHUD.dismiss()
                            self.showMessage(setError!.localizedDescription, messageType: .error)
                        }
                })
            }
        })
    }
    
    // MARK: - UIImagePickerController delegate
    
    @IBAction func setImage(_ sender: Any) {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
        let actionView = ActionSheet.create(
            title: "Choose Photo",
            actions: ["From Camera Roll", "Use Camera"],
            handler1: {
                let imagePicker = UIImagePickerController()
                imagePicker.allowsEditing = false
                imagePicker.sourceType = .photoLibrary
                imagePicker.delegate = self
                imagePicker.modalPresentationStyle = .formSheet
                if let font = UIFont(name: "HelveticaNeue-CondensedBold", size: 15) {
                    imagePicker.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.mainColor(), NSFontAttributeName : font]
                }
                imagePicker.navigationBar.tintColor = UIColor.mainColor()
                self.present(imagePicker, animated: true, completion: nil)
        }, handler2: {
            let imagePicker = UIImagePickerController()
            imagePicker.allowsEditing = false
            imagePicker.sourceType = .camera
            imagePicker.delegate = self
            self.present(imagePicker, animated: true, completion: nil)
        })
        actionView?.show()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: {
            if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
                self.avatar = pickedImage.withSize(CGSize(width:256, height:256))
                self.imageButton.setImage(self.avatar!.inCircle(), for: .normal)
            }
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
}

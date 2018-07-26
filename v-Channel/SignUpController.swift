//
//  SignUpController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 22.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD

class SignUpController: UIViewController, TextFieldContainerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, CameraDelegate {
    
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
        
        signUpButton.setupBorder(UIColor.clear, radius: 20)

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tap))
        self.view.addGestureRecognizer(tap)
    }
    
    @objc func tap() {
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
                    Alert.message(title: "error", message: "Avatar image required")
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
                Alert.message(title: "error", message: "Nickname field required", okHandler: {
                    self.nickField.activate(true)
                })
                return false
            }
        }
        if sender == nil || sender == emailField {
            if !emailField.text().isEmail() {
                Alert.message(title: "error", message: "Email should have xxxx@domain.prefix format", okHandler: {
                    self.emailField.activate(true)
                })
                return false
            }
        }
        if sender == nil || sender == passwordField {
            if passwordField.text().isEmpty {
                Alert.message(title: "error", message: "Password field required", okHandler: {
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
                Alert.message(title: "error", message: "Avatar image required")
            }
        }
    }
    
    func emailSignUp() {
        SVProgressHUD.show(withStatus: "SignUp...")
        Auth.auth().createUser(withEmail: emailField.text(), password: passwordField.text(), completion: { firUser, error in
            if error != nil {
                SVProgressHUD.dismiss()
                Alert.message(title: "error", message: (error! as NSError).localizedDescription)
            } else {
                Model.shared.createEmailUser(firUser!.user,
                                             email: self.emailField.text(),
                                             nick: self.nickField.text(),
                                             image: self.avatar!, result:
                    { setError in
                        if setError == nil {
                            Auth.auth().currentUser?.sendEmailVerification(completion: { error in
                                SVProgressHUD.dismiss()
                                if error == nil {
                                    Alert.message(title: "confirmation", message: "Check your mailbox now. You account will be activated after you confirm registration.", okHandler: {
                                        self.goBack()
                                    })
                                } else {
                                    Alert.message(title: "error", message: setError!.localizedDescription)
                                }
                            })
                        } else {
                            SVProgressHUD.dismiss()
                            Alert.message(title: "error", message: setError!.localizedDescription)
                        }
                })
            }
        })
    }
    
    // MARK: - UIImagePickerController delegate
    
    @IBAction func setImage(_ sender: Any) {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
        let selections:[AlertSelection] = [
            AlertSelection(name: "From Camera Roll", handler: {
                let imagePicker = UIImagePickerController()
                imagePicker.allowsEditing = false
                imagePicker.sourceType = .photoLibrary
                imagePicker.delegate = self
                imagePicker.modalPresentationStyle = .formSheet
                if let font = UIFont(name: "HelveticaNeue-CondensedBold", size: 15) {
                    imagePicker.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : MainColor, NSAttributedStringKey.font : font]
                }
                imagePicker.navigationBar.tintColor = MainColor
                self.present(imagePicker, animated: true, completion: nil)
            }),
            AlertSelection(name: "Use Camera", handler: {
                let camera = UIStoryboard(name: "Camera", bundle: nil)
                let cameraController = camera.instantiateViewController(withIdentifier: "Camera") as! CameraController
                cameraController.modalTransitionStyle = .flipHorizontal
                cameraController.delegate = self
                cameraController.isFront = true
                self.present(cameraController, animated: true, completion: nil)
            })]

        Alert.select(title: "Choose Photo".uppercased(), handlers: selections)

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
    
    func didTakePhoto(_ image:UIImage) {
        dismiss(animated: true, completion: {
            self.avatar = image.withSize(CGSize(width:256, height:256))
            self.imageButton.setImage(self.avatar!.inCircle(), for: .normal)
        })
    }

}

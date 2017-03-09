//
//  InviteController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 09.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD

enum InviteError {
    case none
    case notFound
    case alreadyInList
    case errorLoadProfile
}

protocol InviteControllerDelegate {
    func didAddContact(_ contact:User)
}

class InviteController: UITableViewController {

    var delegate:InviteControllerDelegate?
    private var friends:[Any] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("Add Contact")
        setupBackButton()
        
        if let token = UserDefaults.standard.value(forKey: "fbToken") as? String {
            SVProgressHUD.show(withStatus: "Load...")
            let params = ["fields" : "name,picture.width(100).height(100)"]
            let request = FBSDKGraphRequest(graphPath: "me/friends/", parameters: params, tokenString: token, version: nil, httpMethod: nil)
            request!.start(completionHandler: { _, result, fbError in
                if let friendList = result as? [String:Any], let list = friendList["data"] as? [Any] {
                    for item in list {
                        if let profile = item as? [String:Any],
                            let id = profile["id"] as? String,
                            let name = profile["name"] as? String {
                            let friend = ["id": id, "name" : name]
                            self.friends.append(friend)
                        }
                    }
                }
                SVProgressHUD.dismiss()
                self.tableView.reloadData()
            })
        } else {
            byEmail()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "my facebook friends with v-channel"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        let friend = friends[indexPath.row] as! [String:String]
        cell.textLabel?.text = friend["name"]
        cell.textLabel?.font = UIFont.condensedFont()
        cell.textLabel?.textColor = UIColor.mainColor()
        cell.accessoryType = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let friend = friends[indexPath.row] as? [String:String] {
            InviteController.addUser(fieldName: "facebookID", fieldValue: friend["id"]!, result: { user, error in
                switch error {
                case .none:
                    self.delegate?.didAddContact(user!)
                    self.goBack()
                case .alreadyInList:
                    self.showMessage("This user is in list already.", messageType: .information)
                case .notFound:
                    self.showMessage("User not found.", messageType: .error)
                case .errorLoadProfile:
                    self.showMessage("Can not load user profile.", messageType: .error)
                }
            })
        }
    }
    
    @IBAction func byEmail() {
        let alert = EmailInput.getEmail(cancelHandler: {
        }, acceptHandler: { email in
            InviteController.addUser(fieldName: "email", fieldValue: email, result: { user, error in
                switch error {
                case .none:
                    self.delegate?.didAddContact(user!)
                    self.goBack()
                case .alreadyInList:
                    self.showMessage("This user is in list already.", messageType: .information)
                case .notFound:
                    self.showMessage("User not found.", messageType: .error)
                case .errorLoadProfile:
                    self.showMessage("Can not load user profile.", messageType: .error)
                }
            })
        })
        alert?.show()
    }

    class func addUser(fieldName:String, fieldValue:String, result: @escaping(User?, InviteError) -> ()) {
        SVProgressHUD.show(withStatus: "Search...")
        let ref = FIRDatabase.database().reference()
        ref.child("users").queryOrdered(byChild: fieldName).queryEqual(toValue: fieldValue).observeSingleEvent(of: .value, with: { snapshot in
            if let values = snapshot.value as? [String:Any] {
                for uid in values.keys {
                    if uid == currentUser()!.uid! {
                        continue
                    }
                    if Model.shared.contactWithUser(uid) != nil {
                        SVProgressHUD.dismiss()
                        result(nil, .alreadyInList)
                    } else {
                        Model.shared.uploadUser(uid, result: { user in
                            SVProgressHUD.dismiss()
                            if user != nil {
                                result(user, .none)
                            } else {
                                result(nil, .errorLoadProfile)
                            }
                        })
                    }
                    return
                }
                SVProgressHUD.dismiss()
                result(nil, .notFound)
            } else {
                SVProgressHUD.dismiss()
                result(nil, .notFound)
//                self.showMessage("User not found.", messageType: .error)
            }
        })
    }
}

//
//  ContactListController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD
import GoogleSignIn

enum InviteError {
    case none
    case notFound
    case alreadyInList
    case errorLoadProfile
}

class ContactListController: UITableViewController, LoginControllerDelegate, GIDSignInDelegate {

    fileprivate var contacts:[Contact] = []
    
    var inviteEnabled = false
    
    // MARK: - Life cycle
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("My Contacts")
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.refresh),
                                               name: contactNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.refreshStatus),
                                               name: newMessageNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.refreshStatus),
                                               name: readMessageNotification,
                                               object: nil)

        if currentUser() == nil {
            performSegue(withIdentifier: "login", sender: self)
        } else {
            Model.shared.startObservers()
            refresh()
            if currentUser()!.socialType == .google {
                GIDSignIn.sharedInstance().delegate = self
                GIDSignIn.sharedInstance().signInSilently()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if user != nil {
            inviteEnabled = true
        }
    }

    @objc func refresh() {
        if let allContacts = currentUser()!.contacts?.allObjects as? [Contact] {
            contacts.removeAll()
            contacts = allContacts.sorted(by: { contact1, contact2 in
                let result = contact1.name().caseInsensitiveCompare(contact2.name())
                return result == .orderedAscending
            })
        }
        tableView.reloadData()
    }
    
    @objc func refreshStatus() {
        tableView.reloadData()
    }

    func didLogin() {
        dismiss(animated: true, completion: {
            Model.shared.startObservers()
            self.refresh()
        })
    }
    
    func didLogout() {
        for user in contacts {
            Model.shared.deleteUser(user.uid!)
        }
        contacts = []
        tableView.reloadData()
        _ = navigationController?.popViewController(animated: true)
        performSegue(withIdentifier: "login", sender: self)
    }
    
    // MARK: - Invitation
    
    func sendInvite() {
        if let invite = Invites.inviteDialog() {
            invite.setInviteDelegate(self)
            invite.setMessage("\(currentUser()!.name!) invite you to install v-Channel for messaging exchange.")
            invite.setTitle("Invite")
            invite.setDeepLink(deepLink)
            invite.setCallToActionText("Install")
            invite.open()
        }
    }

    @IBAction func addContact(_ sender: Any) {
        TextAlert.getEmail({ email in
            if email != nil {
                self.findUser(fieldName: "email", fieldValue: email!, result: { user, error in
                    switch error {
                    case .none:
                        let contact = Model.shared.addContact(with: user!)
                        self.tableView.beginUpdates()
                        let indexPath = IndexPath(row: self.contacts.count, section: 0)
                        self.contacts.append(contact)
                        self.tableView.insertRows(at: [indexPath], with: .bottom)
                        self.tableView.endUpdates()
                    case .alreadyInList:
                        Alert.message(title: "error", message: "This user is in list already")
                    case .notFound:
                        if self.inviteEnabled {
                            Alert.question(title: "invitation", message: "User not found. Do you want to invite him into v-Channel?", okHandler: {
                                self.sendInvite()
                            }, cancelHandler: {
                                
                            }, okTitle: "Invite", cancelTitle: "Cancel")
                        } else {
                            Alert.message(title: "error", message: "User not found")
                        }
                    case .errorLoadProfile:
                        Alert.message(title: "error", message: "Can not load user profile")
                    }
                })
            }
        })
    }
    
    func findUser(fieldName:String, fieldValue:String, result: @escaping(AppUser?, InviteError) -> ()) {
        SVProgressHUD.show(withStatus: "Search...")
        let ref = Database.database().reference()
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
            }
        })
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 5
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Contact", for: indexPath) as! ContactCell
        cell.contact = contacts[indexPath.row]
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let contact = contacts[indexPath.row]
            if let index = contacts.index(of: contact) {
                tableView.beginUpdates()
                contacts.remove(at: index)
                Model.shared.deleteContact(contact)
                tableView.deleteRows(at: [indexPath], with: .top)
                tableView.endUpdates()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contact = contacts[indexPath.row]
        switch contact.getContactStatus() {
        case .requested:
            if contact.initiator != currentUser()!.uid, let user = Model.shared.getUser(contact.initiator!) {
                Alert.question(title: "invitation", message: "\(user.name!) ask you to add him into contact list. Are you agree?", okHandler: {
                    Model.shared.approveContact(contact)
                }, cancelHandler: {
                    Model.shared.rejectContact(contact)
                    self.refresh()
                })
            }
        case .approved:
            self.performSegue(withIdentifier: "chat", sender: contact)
        default:
            break
        }
    }

    // MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "chat" {
            if let contact = sender as? Contact {
                if let user = Model.shared.getUser(contact.uid!) {
                    if user.token == nil {
                        Alert.message(title: "error", message: "\(user.name!) does not available for chat now")
                        return false
                    }
                }
            }
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "login" {
            let nav = segue.destination as! UINavigationController
            let controller = nav.topViewController as! LoginController
            controller.delegate = self
        } else if segue.identifier == "chat" {
            let controller = segue.destination as! ChatController
            if let contact = sender as? Contact {
                if contact.getContactStatus() == .approved {
                    if contact.initiator! == currentUser()!.uid! {
                        controller.opponent = Model.shared.getUser(contact.requester!)
                    } else {
                        controller.opponent = Model.shared.getUser(contact.initiator!)
                    }
                }
            }
        }
    }
}
extension ContactListController : InviteDelegate {
    
    func inviteFinished(withInvitations invitationIds: [String], error: Error?) {
        if let error = error {
            if error.localizedDescription != "Canceled by User" {
                Alert.message(title: "error", message: "Can not send invite. \(error.localizedDescription)")
            }
        } else {
            Alert.message(title: "success", message: "\(invitationIds.count) invites was sent")
        }
    }
}

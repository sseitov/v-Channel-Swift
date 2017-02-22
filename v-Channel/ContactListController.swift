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

class ContactListController: UITableViewController {

    fileprivate var contacts:[User] = []

    fileprivate let IP_STUN_SERVER_VOIP = "95.31.31.166"
    //    fileprivate let IP_STUN_SERVER_VOIP = "192.168.1.15"
    fileprivate let IP_AUDIO_PORT_VOIP = "6888"
    
    fileprivate var ipGetter:IP_Getter?
    fileprivate var gateway:CallGatewayInfo?
    fileprivate var getterTimer:Timer?
    
    fileprivate var inCall:[String:Any]? {
        didSet {
            if inCall == nil {
                (UIApplication.shared.delegate as! AppDelegate).ringStop()
            }
            tableView.reloadData()
        }
    }
    
    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.addContactNotify(_:)),
                                               name: contactAddNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.updateContactNotify(_:)),
                                               name: contactUpdateNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.deleteContactNotify(_:)),
                                               name: contactDeleteNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.incommingCall(_:)),
                                               name: incommingCallNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.hangUpCall(_:)),
                                               name: hangUpCallNotification,
                                               object: nil)
        if currentUser() == nil {
            performSegue(withIdentifier: "login", sender: self)
        } else {
            Model.shared.startObservers()
            contacts = Model.shared.myContacts()
            tableView.reloadData()
            gateway = nil
            ipGetter = IP_Getter(IP_STUN_SERVER_VOIP, port: IP_AUDIO_PORT_VOIP)
            getterTimer = Timer.scheduledTimer(timeInterval: 0.4, target: self, selector: #selector(self.checkGateway(_:)), userInfo: nil, repeats: true);
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func checkGateway(_ timer:Timer) {
        if ipGetter != nil && ipGetter!.check() {
            timer.invalidate()
            gateway = CallGatewayInfo(ipGetter: ipGetter)
        } else {
            print("No gateway yet\n")
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "contact", for: indexPath) as! ContactCell
        let user = contacts[indexPath.row]
        cell.user = user
        cell.contact = Model.shared.contactWithUser(user.uid!)
        if inCall != nil && inCall!["group"] == nil && ((inCall!["from"] as! String) == user.uid!) {
            cell.incomming = true
        } else {
            cell.incomming = false
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let user = contacts[indexPath.row]
            if let contact = Model.shared.contactWithUser(user.uid!) {
                let question = createQuestion("Do you want to delete \(user.name!) from contact list?", acceptTitle: "Delete", cancelTitle: "Cancel", acceptHandler: {
                    
                    SVProgressHUD.show(withStatus: "Delete...")
                    Model.shared.deleteContact(contact, completion: {
                        SVProgressHUD.dismiss()
                        tableView.beginUpdates()
                        self.contacts.remove(at: indexPath.row)
                        tableView.deleteRows(at: [indexPath], with: .top)
                        tableView.endUpdates()
                    })
                })
                question?.show()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = contacts[indexPath.row]
        if let contact = Model.shared.contactWithUser(user.uid!) {
            if contact.contactStatus() == .requested {
                if contact.requester! == currentUser()!.uid! {
                    let question = ActionSheet.create(title: "\(user.name!) ask you to add him into contact list",
                        actions: ["Add to list", "Reject request"], handler1: {
                            Model.shared.approveContact(contact)
                            self.tableView.reloadRows(at: [indexPath], with: .fade)
                    }, handler2: {
                        SVProgressHUD.show(withStatus: "Delete...")
                        Model.shared.deleteContact(contact, completion: {
                            SVProgressHUD.dismiss()
                            tableView.beginUpdates()
                            self.contacts.remove(at: indexPath.row)
                            tableView.deleteRows(at: [indexPath], with: .top)
                            tableView.endUpdates()
                        })
                    })
                    question?.firstButton.backgroundColor = UIColor.mainColor()
                    question?.secondButton.backgroundColor = UIColor.errorColor()
                    question?.cancelButton.setTitle("Not now", for: .normal)
                    question?.show()
                } else {
                    showMessage("You are wait approval from \(user.name!).", messageType: .information)
                }
            } else if contact.contactStatus() == .rejected {
                let question = createQuestion("Contact was rejected. Are you want to delete it?", acceptTitle: "Delete", cancelTitle: "Not now", acceptHandler: {
                    SVProgressHUD.show(withStatus: "Delete...")
                    Model.shared.deleteContact(contact, completion: {
                        SVProgressHUD.dismiss()
                        tableView.beginUpdates()
                        self.contacts.remove(at: indexPath.row)
                        tableView.deleteRows(at: [indexPath], with: .top)
                        tableView.endUpdates()
                    })
                })
                question?.show()
            } else {
                if inCall != nil {
                    let fromID = inCall!["from"] as! String
                    let callID = inCall!["uid"] as! String
                    if (fromID == user.uid!) {
                        let alert = createQuestion("Do you want accept call from \(user.name!)",
                            acceptTitle: "Accept",
                            cancelTitle: "Reject",
                            acceptHandler: {
                                self.performSegue(withIdentifier: "personalCall", sender: self.inCall)
                                self.inCall = nil
                        },
                            cancelHandler: {
                                Model.shared.hangUpCall(callID: callID)
                                self.inCall = nil
                        })
                        alert?.show()
                    } else {
                        if gateway != nil {
                            Model.shared.hangUpCall(callID: callID)
                            performSegue(withIdentifier: "personalCall", sender: user)
                            self.inCall = nil
                        } else {
                            showMessage("I have not yet received public IP address. Need some wait...", messageType: .information)
                            self.inCall = nil
                        }
                    }
                } else {
                    if gateway != nil {
                        performSegue(withIdentifier: "personalCall", sender: user)
                    } else {
                        showMessage("I have not yet received public IP address. Need some wait...", messageType: .information)
                    }
                }
            }
        }
    }
    
    // MARK: - Contact management
    
    func doAddContact() {
        let alert = EmailInput.getEmail(cancelHandler: {
        }, acceptHandler: { email in
            SVProgressHUD.show(withStatus: "Search...")
            let ref = FIRDatabase.database().reference()
            ref.child("users").queryOrdered(byChild: "email").queryEqual(toValue: email).observeSingleEvent(of: .value, with: { snapshot in
                if let values = snapshot.value as? [String:Any] {
                    for uid in values.keys {
                        if uid == currentUser()!.uid! {
                            continue
                        }
                        if Model.shared.contactWithUser(uid) != nil {
                            SVProgressHUD.dismiss()
                            self.showMessage("This user is in list already.", messageType: .information)
                        } else {
                            Model.shared.getEmailUser(uid, result: { user in
                                SVProgressHUD.dismiss()
                                if user != nil {
                                    Model.shared.addContact(with: user!)
                                    self.tableView.beginUpdates()
                                    let indexPath = IndexPath(row: self.contacts.count, section: 2)
                                    self.contacts.append(user!)
                                    self.tableView.insertRows(at: [indexPath], with: .bottom)
                                    self.tableView.endUpdates()
                                } else {
                                    self.showMessage("Can not load user profile.", messageType: .error)
                                }
                            })
                        }
                        return
                    }
                    SVProgressHUD.dismiss()
                    self.showMessage("User not found.", messageType: .error)
                } else {
                    SVProgressHUD.dismiss()
                    self.showMessage("User not found.", messageType: .error)
                }
            })
        })
        alert?.show()
    }
    
    @IBAction func addContact(_ sender: Any) {
        let alert = ActionSheet.create(title: "What do you want to do?", actions: ["Add personal contact", "Create chat group"], handler1: {
            self.doAddContact()
        }, handler2: {
            self.performSegue(withIdentifier: "group", sender: nil)
        })
        alert?.show()
    }
    
    func addContactNotify(_ notify:Notification) {
        if let user = notify.object as? User {
            self.tableView.beginUpdates()
            let indexPath = IndexPath(row: self.contacts.count, section: 2)
            self.contacts.append(user)
            self.tableView.insertRows(at: [indexPath], with: .bottom)
            self.tableView.endUpdates()
        }
    }
    
    func updateContactNotify(_ notify:Notification) {
        if let user = notify.object as? User {
            if let index = self.contacts.index(of: user) {
                let indexPath = IndexPath(row: index, section: 2)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
    }
    
    func deleteContactNotify(_ notify:Notification) {
        self.contacts = Model.shared.myContacts()
        self.tableView.reloadData()
    }
    
    // MARK: - Call management
    
    func incommingCall(_ notify:Notification) {
        let callID = notify.object as! String
        let ref = FIRDatabase.database().reference()
        ref.child("calls").child(callID).observeSingleEvent(of: .value, with: { result in
            if var call = result.value as? [String:Any] {
                call["uid"] = callID
                self.inCall = call
            }
        })
    }
    
    func hangUpCall(_ notify:Notification) {
        let callID = notify.object as! String
        if (self.inCall != nil) && ((self.inCall!["uid"] as! String) == callID) {
            self.inCall = nil
        }
    }

    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "personalCall" {
            let nav = segue.destination as! UINavigationController
            let controller = nav.topViewController as! CallController
            if let contact = sender as? User {
                controller.contact = contact
                controller.gateway = self.gateway
            } else {
                controller.incommingCall = sender as? [String:Any]
            }
        }
    }


}

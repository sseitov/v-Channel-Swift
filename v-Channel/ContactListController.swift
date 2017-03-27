//
//  ContactListController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase

class ContactListController: UITableViewController, LoginControllerDelegate, InviteControllerDelegate, CallControllerDelegate {

    fileprivate var contacts:[Contact] = []
    
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
        }
    }
    
    func refresh() {
        if let allContacts = currentUser()!.contacts?.allObjects as? [Contact] {
            contacts.removeAll()
            contacts = allContacts
        }
        tableView.reloadData()
        if IS_PAD() {
            if contacts.count > 0 {
                performSegue(withIdentifier: "chat", sender: contacts[0])
            } else {
                performSegue(withIdentifier: "chat", sender: nil)
            }
        }
    }
    
    func refreshStatus() {
        tableView.reloadData()
    }

    func didLogin() {
        dismiss(animated: true, completion: {
            Model.shared.startObservers()
            self.refresh()
        })
    }
    
    func didLogout() {
        if IS_PAD() {
            performSegue(withIdentifier: "personalCall", sender: nil)
        }
        for user in contacts {
            Model.shared.deleteUser(user.uid!)
        }
        contacts = []
        tableView.reloadData()
        _ = navigationController?.popViewController(animated: true)
        performSegue(withIdentifier: "login", sender: self)
    }

    func didAddContact(_ user: User) {
        let contact = Model.shared.addContact(with: user)
        self.tableView.beginUpdates()
        let indexPath = IndexPath(row: self.contacts.count, section: 0)
        self.contacts.append(contact)
        self.tableView.insertRows(at: [indexPath], with: .bottom)
        self.tableView.endUpdates()
    }
    
    func callDidFinish(_ user:User) {
        if IS_PAD() {
            let contact = Model.shared.contactWithUser(user.uid!)
            performSegue(withIdentifier: "chat", sender: contact)
        } else {
            _ = navigationController?.popViewController(animated: true)
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
                if contacts.count == 0 && IS_PAD() {
                    performSegue(withIdentifier: "chat", sender: nil)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contact = contacts[indexPath.row]
        switch contact.getContactStatus() {
        case .requested:
            if contact.initiator != currentUser()!.uid, let user = Model.shared.getUser(contact.initiator!) {
                let question = createQuestion("\(user.name!) ask you to add him into contact list. Are you agree?",
                    acceptTitle: "Yes", cancelTitle: "No",
                    acceptHandler: {
                        Model.shared.approveContact(contact)
                }, cancelHandler: {
                    Model.shared.rejectContact(contact)
                    self.refresh()
                })
                question?.show()
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
                        self.showMessage("\(user.name!) does not available for chat now.", messageType: .information)
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
            let nav = segue.destination as! UINavigationController
            let controller = nav.topViewController as! ChatController
            if let contact = sender as? Contact {
                if contact.getContactStatus() == .approved {
                    if contact.initiator! == currentUser()!.uid! {
                        controller.user = Model.shared.getUser(contact.requester!)
                    } else {
                        controller.user = Model.shared.getUser(contact.initiator!)
                    }
                }
                controller.callHost = self
            }
        } else if segue.identifier == "settings" {
            let controller = segue.destination as! SettingsController
            controller.delegate = self
        } else if segue.identifier == "addContact" {
            let controller = segue.destination as! InviteController
            controller.delegate = self
        }
    }


}

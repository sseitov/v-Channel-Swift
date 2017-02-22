//
//  Model.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//


import UIKit
import CoreData
import Firebase
import AFNetworking

func currentUser() -> User? {
    if let user = FIRAuth.auth()?.currentUser {
        return user.isEmailVerified ? Model.shared.getUser(user.uid) : nil
    } else {
        return nil
    }
}

func generateUDID() -> String {
    return UUID().uuidString
}

enum PushType:Int {
    case none = 0
    case incommingCall = 1
    case hangUpCall = 2
}

let incommingCallNotification = Notification.Name("INCOMMING_CALL")
let acceptCallNotification = Notification.Name("ACCEPT_CALL")
let hangUpCallNotification = Notification.Name("HANGUP_CALL")

let contactAddNotification = Notification.Name("ADD_CONTACT")
let contactUpdateNotification = Notification.Name("UPDATE_CONTACT")
let contactDeleteNotification = Notification.Name("DELETE_CONTACT")


fileprivate let firStorage = "gs://v-channel-679e6.appspot.com"
fileprivate let pushServerKey = "AAAAnbgiMKU:APA91bEAODIVeRXzRh0qB65iG0VldafHQULvRyabbmxILr5a7RPeygUTSSCHIHHFNuPR5czeWAVDP4KcxVQFedN-GTqKieMUGomcCMo_y38P_69B7IqVWrIQY_uQ9QFC8LYnXJ1Tdo5a"

class Model: NSObject {
    
    static let shared = Model()
    
    private override init() {
        super.init()
    }
    
    // MARK: - CoreData stack
    
    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "vChannel", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("vChannel.sqlite")
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        } catch {
            print("CoreData data error: \(error)")
        }
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                print("Saved data error: \(error)")
            }
        }
    }
    
    
    // MARK: - SignOut from cloud
    
    func signOut(_ completion: @escaping() -> ()) {
        let ref = FIRDatabase.database().reference()
        let currentID = currentUser()!.uid!
        ref.child("tokens").child(currentUser()!.uid!).removeValue(completionBlock: { _, _ in
            ref.child("users").child(currentUser()!.uid!).removeValue(completionBlock: { _, _ in
                let user = FIRAuth.auth()?.currentUser
                user?.delete { _ in
                    self.deleteUser(currentID)
                    try? FIRAuth.auth()?.signOut()
                    self.newTokenRefHandle = nil
                    self.updateTokenRefHandle = nil
                    self.newCallRefHandle = nil
                    self.deleteCallRefHandle = nil
                    self.newContactRefHandle = nil
                    self.updateContactRefHandle = nil
                    self.deleteContactRefHandle = nil
                    completion()
                }
            })
        })
    }
    
    // MARK: - Cloud observers
    
    func startObservers() {
        if newTokenRefHandle == nil {
            observeTokens()
        }
        if newContactRefHandle == nil {
            observeContacts()
        }
        if newCallRefHandle == nil {
            observeCalls()
        }
    }
    
    lazy var storageRef: FIRStorageReference = FIRStorage.storage().reference(forURL: firStorage)
    
    private var newTokenRefHandle: FIRDatabaseHandle?
    private var updateTokenRefHandle: FIRDatabaseHandle?
    
    private var newCallRefHandle: FIRDatabaseHandle?
    private var deleteCallRefHandle: FIRDatabaseHandle?
    
    private var newContactRefHandle: FIRDatabaseHandle?
    private var updateContactRefHandle: FIRDatabaseHandle?
    private var deleteContactRefHandle: FIRDatabaseHandle?
    
    // MARK: - User table
    
    func createEmailUser(_ user:FIRUser, email:String, nick:String, image:UIImage, result: @escaping(NSError?) -> ()) {
        let cashedUser = createUser(user.uid)
        cashedUser.email = email
        cashedUser.name = nick
        cashedUser.avatar = UIImagePNGRepresentation(image) as NSData?
        saveContext()
        let meta = FIRStorageMetadata()
        meta.contentType = "image/png"
        self.storageRef.child(generateUDID()).put(cashedUser.avatar as! Data, metadata: meta, completion: { metadata, error in
            if error != nil {
                result(error as NSError?)
            } else {
                let ref = FIRDatabase.database().reference()
                let data:[String : Any] = ["email": cashedUser.email!, "name": cashedUser.name!, "image": metadata!.path!]
                ref.child("users").child(cashedUser.uid!).setValue(data)
                result(nil)
            }
        })
    }
    
    func getEmailUser(_ uid:String, result: @escaping(User?) -> ()) {
        if let existingUser = getUser(uid) {
            result(existingUser)
        } else {
            let ref = FIRDatabase.database().reference()
            ref.child("users").child(uid).observeSingleEvent(of: .value, with: { snapshot in
                if let userData = snapshot.value as? [String:Any] {
                    let user = self.createUser(uid)
                    user.email = userData["email"] as? String
                    user.name = userData["name"] as? String
                    let imageURL = userData["image"] as? String
                    let ref = self.storageRef.child(imageURL!)
                    ref.data(withMaxSize: INT64_MAX, completion: { data, error in
                        user.avatar = data as NSData?
                        self.getUserToken(uid, token: { token in
                            user.token = token
                            self.saveContext()
                            result(user)
                        })
                    })
                } else {
                    result(nil)
                }
            })
        }
    }
    
    fileprivate func getUserToken(_ uid:String, token: @escaping(String?) -> ()) {
        let ref = FIRDatabase.database().reference()
        ref.child("tokens").child(uid).observeSingleEvent(of: .value, with: { snapshot in
            if let result = snapshot.value as? String {
                token(result)
            } else {
                token(nil)
            }
        })
    }
    
    func createUser(_ uid:String) -> User {
        var user = getUser(uid)
        if user == nil {
            user = NSEntityDescription.insertNewObject(forEntityName: "User", into: managedObjectContext) as? User
            user!.uid = uid
        }
        return user!
    }
    
    func getUser(_ uid:String) -> User? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let user = try? managedObjectContext.fetch(fetchRequest).first as? User {
            return user
        } else {
            return nil
        }
    }
    
    func deleteUser(_ uid:String) {
        if let user = getUser(uid) {
            self.managedObjectContext.delete(user)
            self.saveContext()
        }
    }
    
    func publishToken(_ user:FIRUser,  token:String) {
        let ref = FIRDatabase.database().reference()
        ref.child("tokens").child(user.uid).setValue(token)
    }
    
    fileprivate func observeTokens() {
        let ref = FIRDatabase.database().reference()
        let coordQuery = ref.child("tokens").queryLimited(toLast:25)
        
        newTokenRefHandle = coordQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if let user = self.getUser(snapshot.key) {
                if let token = snapshot.value as? String {
                    user.token = token
                    self.saveContext()
                }
            }
        })
        
        updateTokenRefHandle = coordQuery.observe(.childChanged, with: { (snapshot) -> Void in
            if let user = self.getUser(snapshot.key) {
                if let token = snapshot.value as? String {
                    user.token = token
                    self.saveContext()
                }
            }
        })
    }
    
    func myContacts() -> [User] {
        if let contacts = currentUser()!.contacts?.allObjects as? [Contact] {
            var users:[User] = []
            for contact in contacts {
                let userID = contact.initiator! == currentUser()!.uid! ? contact.requester! : contact.initiator!
                if let user = getUser(userID) {
                    users.append(user)
                }
            }
            return users.sorted(by: { user1, user2 in
                return user1.name! > user2.name!
            })
        } else {
            return []
        }
    }
    
    // MARK: - Contacts table
    
    func createContact(_ uid:String) -> Contact {
        var contact = getContact(uid)
        if contact == nil {
            contact = NSEntityDescription.insertNewObject(forEntityName: "Contact", into: managedObjectContext) as? Contact
            contact!.uid = uid
        }
        return contact!
    }
    
    func getContact(_ uid:String) -> Contact? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let contact = try? managedObjectContext.fetch(fetchRequest).first as? Contact {
            return contact
        } else {
            return nil
        }
    }
    
    func addContact(with:User) {
        let contact = createContact(generateUDID())
        contact.initiator = currentUser()!.uid
        contact.requester = with.uid!
        contact.status = ContactStatus.requested.rawValue
        contact.owner = currentUser()
        currentUser()?.addToContacts(contact)
        
        let ref = FIRDatabase.database().reference()
        ref.child("contacts").child(contact.uid!).setValue(contact.getData())
        pushContactRequest(to: with)
    }
    
    func approveContact(_ contact:Contact) {
        let ref = FIRDatabase.database().reference()
        contact.status = ContactStatus.approved.rawValue
        ref.child("contacts").child(contact.uid!).setValue(contact.getData())
    }
    
    func rejectContact(_ contact:Contact) {
        let ref = FIRDatabase.database().reference()
        contact.status = ContactStatus.rejected.rawValue
        ref.child("contacts").child(contact.uid!).setValue(contact.getData())
    }
    
    func deleteContact(_ contact:Contact, completion: @escaping() -> ()) {
        currentUser()?.removeFromContacts(contact)
        let ref = FIRDatabase.database().reference()
        ref.child("contacts").child(contact.uid!).removeValue(completionBlock: { _, _ in
            self.managedObjectContext.delete(contact)
            self.saveContext()
            completion()
        })
    }
    
    fileprivate func observeContacts() {
        let ref = FIRDatabase.database().reference()
        let contactQuery = ref.child("contacts").queryLimited(toLast:25)
        
        newContactRefHandle = contactQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if self.getContact(snapshot.key) == nil {
                if let contactData = snapshot.value as? [String:Any] {
                    if let from = contactData["initiator"] as? String, let to = contactData["requester"] as? String {
                        if from == currentUser()!.uid! || to == currentUser()!.uid {
                            let userID = (from == currentUser()!.uid!) ? to : from
                            self.getEmailUser(userID, result: { user in
                                if user != nil {
                                    let contact = self.createContact(snapshot.key)
                                    contact.owner = currentUser()
                                    currentUser()?.addToContacts(contact)
                                    contact.setData(contactData)
                                    NotificationCenter.default.post(name: contactAddNotification, object: user)
                                }
                            })
                        }
                    }
                }
            }
        })
        
        updateContactRefHandle = contactQuery.observe(.childChanged, with: { (snapshot) -> Void in
            if let contact = self.getContact(snapshot.key) {
                if let contactData = snapshot.value as? [String:Any] {
                    if let from = contactData["initiator"] as? String, let to = contactData["requester"] as? String {
                        if from == currentUser()!.uid, let toUser = self.getUser(to) {
                            contact.setData(contactData)
                            NotificationCenter.default.post(name: contactUpdateNotification, object: toUser)
                        }
                    }
                }
            }
        })
        
        deleteContactRefHandle = contactQuery.observe(.childRemoved, with: { (snapshot) -> Void in
            if let contact = self.getContact(snapshot.key) {
                if currentUser()!.containsContact(contact: contact) {
                    currentUser()!.removeFromContacts(contact)
                    self.managedObjectContext.delete(contact)
                    self.saveContext()
                    NotificationCenter.default.post(name: contactDeleteNotification, object: nil)
                }
            }
        })
        
    }
    
    func contactWithUser(_ uid:String) -> Contact? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        let predicate1  = NSPredicate(format: "initiator == %@", uid)
        let predicate2 = NSPredicate(format: "requester == %@", uid)
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicate1, predicate2])
        
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Contact] {
            return all.first
        } else {
            return nil
        }
    }
    
    // MARK: - Push notifications
    
    fileprivate lazy var httpManager:AFHTTPSessionManager = {
        let manager = AFHTTPSessionManager(baseURL: URL(string: "https://fcm.googleapis.com/fcm/"))
        manager.requestSerializer = AFJSONRequestSerializer()
        manager.requestSerializer.setValue("application/json", forHTTPHeaderField: "Content-Type")
        manager.requestSerializer.setValue("key=\(pushServerKey)", forHTTPHeaderField: "Authorization")
        manager.responseSerializer = AFHTTPResponseSerializer()
        return manager
    }()
    
    fileprivate func pushIncommingCall(to:User) {
        if to.token != nil {
            let notification:[String:Any] = [
                "title" : "v-Chanel call",
                "body" : "Call from \(currentUser()!.name!)",
                "content_available": true]
            let data:[String:Int] = ["pushType" : PushType.incommingCall.rawValue]
            
            let message:[String:Any] = ["to" : to.token!, "priority" : "high", "notification" : notification, "data" : data]
            httpManager.post("send", parameters: message, progress: nil, success: { task, response in
                print("SEND PUSH CALL SUCCESS")
            }, failure: { task, error in
                print("SEND PUSH CALL ERROR: \(error)")
            })
        } else {
            print("USER HAVE NO TOKEN")
        }
    }
    
    func pushHangUpCall(to:User) {
        if to.token != nil {
            let data:[String:Int] = ["pushType" : PushType.hangUpCall.rawValue]
            let message:[String:Any] = ["to" : to.token!, "priority" : "high", "data" : data]
            httpManager.post("send", parameters: message, progress: nil, success: { task, response in
                print("SEND PUSH CALL SUCCESS")
            }, failure: { task, error in
                print("SEND PUSH CALL ERROR: \(error)")
            })
        } else {
            print("USER HAVE NO TOKEN")
        }
    }
    
    fileprivate func pushContactRequest(to:User) {
        if to.token != nil {
            let notification:[String:Any] = [
                "title" : "SimpleVOIP request",
                "body" :"\(currentUser()!.name!) ask you to add him into contact list",
                "sound":"default",
                "content_available": true]
            let message:[String:Any] = ["to": to.token!, "priority": "high", "notification": notification]
            httpManager.post("send", parameters: message, progress: nil, success: { task, response in
                print("SEND PUSH CONTACT REQUEST SUCCESS")
            }, failure: { task, error in
                print("SEND PUSH ERROR: \(error)")
            })
        } else {
            print("USER HAVE NO TOKEN")
        }
    }
    
    // MARK: - VOIP calls
    
    func makeCall(to:User, ip:String, port:String) -> String {
        let ref = FIRDatabase.database().reference()
        let uid = generateUDID()
        let data:[String:Any] = ["from" : currentUser()!.uid!, "ip" : ip, "port" : port, "to" : to.uid!]
        ref.child("calls").child(uid).setValue(data)
        pushIncommingCall(to: to)
        return uid
    }
    
    func hangUpCall(callID:String) {
        let ref = FIRDatabase.database().reference()
        ref.child("calls").child(callID).removeValue()
    }
    
    fileprivate func observeCalls() {
        let ref = FIRDatabase.database().reference()
        let callQuery = ref.child("calls").queryLimited(toLast:25)
        
        newCallRefHandle = callQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if let call = snapshot.value as? [String:Any], let to = call["to"] as? String {
                if to == currentUser()!.uid! {
                    NotificationCenter.default.post(name: incommingCallNotification, object: snapshot.key)
                }
            }
        })
        
        deleteCallRefHandle = callQuery.observe(.childRemoved, with: { (snapshot) -> Void in
            NotificationCenter.default.post(name: hangUpCallNotification, object: snapshot.key)
        })
        
    }

}

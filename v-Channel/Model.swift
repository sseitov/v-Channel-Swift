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
import SDWebImage
import GoogleSignIn
import AFNetworking
import CoreLocation

func currentUser() -> AppUser? {
    if let firUser = Auth.auth().currentUser {
        if let user = Model.shared.getUser(firUser.uid) {
            if user.socialType == .email {
                return (firUser.isEmailVerified || testUser(user.email!)) ? user : nil
            } else {
                return user;
            }
        } else {
            return nil;
        }
    } else {
        return nil
    }
}

func testUser(_ user:String) -> Bool {
    return user == "user1@test.ru" || user == "user2@test.ru"
}

func generateUDID() -> String {
    return UUID().uuidString
}

enum PushType:Int {
    case none = 0
    case incommingCall = 1
    case hangUpCall = 2
    case newMessage = 3
}

let newMessageNotification = Notification.Name("NEW_MESSAGE")
let deleteMessageNotification = Notification.Name("DELETE_MESSAGE")
let readMessageNotification = Notification.Name("READ_MESSAGE")

let acceptCallNotification = Notification.Name("ACCEPT_CALL")
let hangUpCallNotification = Notification.Name("HANGUP_CALL")

let contactNotification = Notification.Name("CONTACT")

class Model: NSObject {
    
    static let shared = Model()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Date formatter
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
    
    lazy var textDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    lazy var textYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

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
        let ref = Database.database().reference()
        ref.child("tokens").child(currentUser()!.uid!).removeValue(completionBlock: { _, _ in
            try? Auth.auth().signOut()
            self.newMessageRefHandle = nil
            self.deleteMessageRefHandle = nil
            self.newTokenRefHandle = nil
            self.updateTokenRefHandle = nil
            self.newCallRefHandle = nil
            self.updateCallRefHandle = nil
            self.deleteCallRefHandle = nil
            self.newContactRefHandle = nil
            self.updateContactRefHandle = nil
            self.deleteContactRefHandle = nil
            completion()
        })
    }
    
    // MARK: - Cloud observers
    
    func startObservers() {
        if newMessageRefHandle == nil {
            observeMessages()
        }
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
    
    lazy var storageRef: StorageReference = Storage.storage().reference(forURL: firStorage)
    
    private var newMessageRefHandle: DatabaseHandle?
    private var deleteMessageRefHandle: DatabaseHandle?

    private var newTokenRefHandle: DatabaseHandle?
    private var updateTokenRefHandle: DatabaseHandle?
    
    private var newCallRefHandle: DatabaseHandle?
    private var updateCallRefHandle: DatabaseHandle?
    private var deleteCallRefHandle: DatabaseHandle?
    
    private var newContactRefHandle: DatabaseHandle?
    private var updateContactRefHandle: DatabaseHandle?
    private var deleteContactRefHandle: DatabaseHandle?
    
    // MARK: - User table
    
    func createUser(_ uid:String) -> AppUser {
        var user = getUser(uid)
        if user == nil {
            user = NSEntityDescription.insertNewObject(forEntityName: "AppUser", into: managedObjectContext) as? AppUser
            user!.uid = uid
        }
        return user!
    }
    
    func getUser(_ uid:String) -> AppUser? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AppUser")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let user = try? managedObjectContext.fetch(fetchRequest).first as? AppUser {
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
    
    func uploadUser(_ uid:String, result: @escaping(AppUser?) -> ()) {
        if let existingUser = getUser(uid) {
            result(existingUser)
        } else {
            let ref = Database.database().reference()
            ref.child("users").child(uid).observeSingleEvent(of: .value, with: { snapshot in
                if let userData = snapshot.value as? [String:Any] {
                    let user = self.createUser(uid)
                    user.setData(userData, completion: {
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
    
    func updateUser(_ user:AppUser) {
        saveContext()
        let ref = Database.database().reference()
        ref.child("users").child(user.uid!).setValue(user.getData())
    }

    fileprivate func getUserToken(_ uid:String, token: @escaping(String?) -> ()) {
        let ref = Database.database().reference()
        ref.child("tokens").child(uid).observeSingleEvent(of: .value, with: { snapshot in
            if let result = snapshot.value as? String {
                token(result)
            } else {
                token(nil)
            }
        })
    }
    
    func publishToken(_ user:AppUser,  token:String) {
        user.token = token
        saveContext()
        let ref = Database.database().reference()
        ref.child("tokens").child(user.uid!).setValue(token)
    }
    
    fileprivate func observeTokens() {
        let ref = Database.database().reference()
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

    func createEmailUser(_ user:User, email:String, nick:String, image:UIImage, result: @escaping(NSError?) -> ()) {
        let cashedUser = createUser(user.uid)
        cashedUser.email = email
        cashedUser.name = nick
        cashedUser.type = Int16(SocialType.email.rawValue)
        cashedUser.avatar = UIImagePNGRepresentation(image) as NSData?
        if let token = Messaging.messaging().fcmToken {
            Model.shared.publishToken(cashedUser, token: token)
        }

        saveContext()
        let meta = StorageMetadata()
        meta.contentType = "image/png"
        self.storageRef.child(generateUDID()).putData(cashedUser.avatar! as Data, metadata: meta, completion: { metadata, error in
            if error != nil {
                result(error as NSError?)
            } else {
                cashedUser.avatarURL = metadata!.path!
                self.updateUser(cashedUser)
                result(nil)
            }
        })
    }
    
    func createFacebookUser(_ user:User, profile:[String:Any], completion: @escaping() -> ()) {
        let cashedUser = createUser(user.uid)
        cashedUser.type = Int16(SocialType.facebook.rawValue)
        cashedUser.facebookID = profile["id"] as? String
        cashedUser.email = profile["email"] as? String
        cashedUser.name = profile["name"] as? String
        if let token = Messaging.messaging().fcmToken {
            Model.shared.publishToken(cashedUser, token: token)
        }

        if let picture = profile["picture"] as? [String:Any] {
            if let data = picture["data"] as? [String:Any] {
                cashedUser.avatarURL = data["url"] as? String
            }
        }
        if cashedUser.avatarURL != nil, let url = URL(string: cashedUser.avatarURL!) {
            SDWebImageDownloader.shared().downloadImage(with: url, options: [], progress: nil, completed: { _, data, error, _ in
                if data != nil {
                    cashedUser.avatar = data as NSData?
                }
                self.updateUser(cashedUser)
                completion()
            })
        } else {
            cashedUser.avatar = nil
            updateUser(cashedUser)
            completion()
        }
    }
    
    func createGoogleUser(_ user:User, googleProfile: GIDProfileData!, completion: @escaping() -> ()) {
        let cashedUser = createUser(user.uid)
        cashedUser.type = Int16(SocialType.google.rawValue)
        cashedUser.email = googleProfile.email
        cashedUser.name = googleProfile.name
        if let token = Messaging.messaging().fcmToken {
            Model.shared.publishToken(cashedUser, token: token)
        }

        if googleProfile.hasImage {
            if let url = googleProfile.imageURL(withDimension: 100) {
                cashedUser.avatarURL = url.absoluteString
            }
        }
        if cashedUser.avatarURL != nil, let url = URL(string: cashedUser.avatarURL!) {
            SDWebImageDownloader.shared().downloadImage(with: url, options: [], progress: nil, completed: { _, data, error, _ in
                if data != nil {
                    cashedUser.avatar = data as NSData?
                }
                self.updateUser(cashedUser)
                completion()
            })
        } else {
            cashedUser.avatar = nil
            updateUser(cashedUser)
            completion()
        }
    }

    func myContacts() -> [AppUser] {
        if let contacts = currentUser()!.contacts?.allObjects as? [Contact] {
            var users:[AppUser] = []
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
    
    func addContact(with:AppUser) -> Contact {
        let contact = createContact(generateUDID())
        contact.initiator = currentUser()!.uid
        contact.requester = with.uid!
        contact.status = ContactStatus.requested.rawValue
        contact.owner = currentUser()
        currentUser()?.addToContacts(contact)
        
        let ref = Database.database().reference()
        ref.child("contacts").child(contact.uid!).setValue(contact.getData())
        pushContactRequest(to: with)
        return contact
    }
    
    func approveContact(_ contact:Contact) {
        let ref = Database.database().reference()
        contact.status = ContactStatus.approved.rawValue
        ref.child("contacts").child(contact.uid!).setValue(contact.getData())
    }
    
    func rejectContact(_ contact:Contact) {
        let ref = Database.database().reference()
        contact.status = ContactStatus.rejected.rawValue
        ref.child("contacts").child(contact.uid!).setValue(contact.getData())
    }
    
    func deleteContact(_ contact:Contact) {
        currentUser()?.removeFromContacts(contact)
        let ref = Database.database().reference()
        ref.child("contacts").child(contact.uid!).removeValue()
        self.managedObjectContext.delete(contact)
        self.saveContext()
    }
    
    fileprivate func observeContacts() {
        let ref = Database.database().reference()
        let contactQuery = ref.child("contacts").queryLimited(toLast:25)
        
        newContactRefHandle = contactQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if self.getContact(snapshot.key) == nil {
                if let contactData = snapshot.value as? [String:Any] {
                    if let from = contactData["initiator"] as? String, let to = contactData["requester"] as? String {
                        if from == currentUser()!.uid! || to == currentUser()!.uid! {
                            self.uploadUser(from, result: { fromUser in
                                if fromUser != nil {
                                    self.uploadUser(to, result: { toUser in
                                        if toUser != nil {
                                            let contact = self.createContact(snapshot.key)
                                            contact.owner = currentUser()
                                            currentUser()?.addToContacts(contact)
                                            contact.setData(contactData)
                                            NotificationCenter.default.post(name: contactNotification, object: nil)
                                        }
                                    })
                                }
                            })
                        }
                    }
                }
            }
        })
        
        updateContactRefHandle = contactQuery.observe(.childChanged, with: { (snapshot) -> Void in
            if let contact = self.getContact(snapshot.key) {
                if let data = snapshot.value as? [String:Any] {
                    contact.setData(data)
                    NotificationCenter.default.post(name: contactNotification, object: contact)
                }
            }
        })
        
        deleteContactRefHandle = contactQuery.observe(.childRemoved, with: { (snapshot) -> Void in
            if let contact = self.getContact(snapshot.key) {
                currentUser()!.removeFromContacts(contact)
                self.managedObjectContext.delete(contact)
                self.saveContext()
                NotificationCenter.default.post(name: contactNotification, object: nil)
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
    
    fileprivate func pushIncommingCall(to:AppUser) {
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
    
    func pushHangUpCall(to:AppUser) {
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
    
    fileprivate func pushContactRequest(to:AppUser) {
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
    
    fileprivate func messagePush(_ text:String, to:AppUser, from:AppUser) {
        if to.token != nil {
            let data:[String:Int] = ["pushType" : PushType.newMessage.rawValue]
            let notification:[String:Any] = ["title" : "New message from \(from.name!):",
                "body": text,
                "sound":"default",
                "content_available": true]
            let message:[String:Any] = ["to" : to.token!, "priority" : "high", "notification" : notification, "data" : data]
            httpManager.post("send", parameters: message, progress: nil, success: { task, response in
            }, failure: { task, error in
                print("SEND PUSH ERROR: \(error)")
            })
        } else {
            print("USER HAVE NO TOKEN")
        }
    }

    // MARK: - VOIP calls

    func makeCall(to:AppUser) -> String {
        let ref = Database.database().reference()
        let uid = generateUDID()
        let data:[String:Any] = ["from" : currentUser()!.uid!,
                                 "to" : to.uid!]
        ref.child("calls").child(uid).setValue(data)
        pushIncommingCall(to: to)
        return uid
    }
    
    func acceptCall(_ callID:String) {
        let ref = Database.database().reference()
        ref.child("calls").child(callID).setValue(["accept" : true])
        
        Ringtone.shared.stop()
        UserDefaults.standard.removeObject(forKey: "incommingCall")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: contactNotification, object: nil)
    }

    func hangUpCall(_ callID:String) {
        let ref = Database.database().reference()
        ref.child("calls").child(callID).removeValue()
        
        Ringtone.shared.stop()
        UserDefaults.standard.removeObject(forKey: "incommingCall")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: contactNotification, object: nil)
    }
    
    fileprivate func observeCalls() {
        let ref = Database.database().reference()
        let callQuery = ref.child("calls").queryLimited(toLast:25)
        
        newCallRefHandle = callQuery.observe(.childAdded, with: { (snapshot) -> Void in
            if let data = snapshot.value as? [String:Any], let to = data["to"] as? String, let from = data["from"] as? String {
                if to == currentUser()!.uid! {
                    Ringtone.shared.play()
                    let call = ["uid" : snapshot.key, "from" : from]
                    UserDefaults.standard.set(call, forKey: "incommingCall")
                    UserDefaults.standard.synchronize()
                    NotificationCenter.default.post(name: contactNotification, object: nil)
                }
            }
        })
        
        updateCallRefHandle = callQuery.observe(.childChanged, with: { (snapshot) -> Void in
            NotificationCenter.default.post(name: acceptCallNotification, object: snapshot.key)
        })
        
        deleteCallRefHandle = callQuery.observe(.childRemoved, with: { (snapshot) -> Void in
            NotificationCenter.default.post(name: hangUpCallNotification, object: snapshot.key)
            if (UserDefaults.standard.object(forKey: "incommingCall") as? [String:Any]) != nil {
                Ringtone.shared.stop()
                UserDefaults.standard.removeObject(forKey: "incommingCall")
                UserDefaults.standard.synchronize()
                NotificationCenter.default.post(name: contactNotification, object: nil)
            }
        })
        
    }
    
    // MARK: - Message table
    
    func createMessage(_ uid:String) -> Message {
        var message = getMessage(uid)
        if message == nil {
            message = NSEntityDescription.insertNewObject(forEntityName: "Message", into: managedObjectContext) as? Message
            message!.uid = uid
        }
        return message!
    }
    
    func getMessage(_ uid:String) -> Message? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let predicate = NSPredicate(format: "uid = %@", uid)
        fetchRequest.predicate = predicate
        if let message = try? managedObjectContext.fetch(fetchRequest).first as? Message {
            return message
        } else {
            return nil
        }
    }
    
    func getMessage(from:AppUser, date:Date) -> Message? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let predicate1 = NSPredicate(format: "from = %@", from.uid!)
        let predicate2 = NSPredicate(format: "date = %@", date as NSDate)
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        if let message = try? managedObjectContext.fetch(fetchRequest).first as? Message {
            return message
        } else {
            return nil
        }
    }
    
    func deleteMessage(_ message:Message, completion: @escaping() -> ()) {
        let ref = Database.database().reference()
        if let image = message.imageURL {
            self.storageRef.child(image).delete(completion: { _ in
                ref.child("messages").child(message.uid!).removeValue(completionBlock:{_, _ in
                    completion()
                })
            })
        } else {
            ref.child("messages").child(message.uid!).removeValue(completionBlock: { _, _ in
                completion()
            })
        }
    }
    
    private func chatPredicate(with:String) -> NSPredicate {
        let predicate1  = NSPredicate(format: "from == %@", with)
        let predicate2 = NSPredicate(format: "to == %@", currentUser()!.uid!)
        let toPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        let predicate3  = NSPredicate(format: "from == %@", currentUser()!.uid!)
        let predicate4 = NSPredicate(format: "to == %@", with)
        let fromPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate3, predicate4])
        return NSCompoundPredicate(orPredicateWithSubpredicates: [toPredicate, fromPredicate])
    }
    
    func chatMessages(with:String) -> [Message] {
        if currentUser() == nil {
            return []
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.predicate = chatPredicate(with: with)
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Message] {
            return all
        } else {
            return []
        }
    }
    
    func unreadCountInChat(_ uid:String) -> Int {
        if currentUser() == nil {
            return 0
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        let predicate = NSPredicate(format: "isNew == YES")
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [chatPredicate(with: uid), predicate])
        
        do {
            return try managedObjectContext.count(for: fetchRequest)
        } catch {
            return 0
        }
    }
    
    func lastMessageInChat(_ uid:String) -> Message? {
        if currentUser() == nil {
            return nil
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.predicate = chatPredicate(with: uid)
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.fetchLimit = 1
        if let all = try? managedObjectContext.fetch(fetchRequest) as! [Message] {
            return all.first
        } else {
            return nil
        }
    }
    
    func allUnreadCount() -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchRequest.predicate = NSPredicate(format: "isNew == YES")
        do {
            return try managedObjectContext.count(for: fetchRequest)
        } catch {
            return 0
        }
    }
    
    func readMessage(_ message:Message) {
        message.isNew = false
        saveContext()
        NotificationCenter.default.post(name: readMessageNotification, object: message)
    }
    
    func sendTextMessage(_ text:String, to:String) {
        let ref = Database.database().reference()
        let dateStr = dateFormatter.string(from: Date())
        let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                        "to" : to,
                                        "text" : text,
                                        "date" : dateStr]
        ref.child("messages").childByAutoId().setValue(messageItem)
        if let toUser = getUser(to) {
            self.messagePush(text, to: toUser, from: currentUser()!)
        }
    }
    
    func sendImageMessage(_ image:UIImage, to:String, result:@escaping (NSError?) -> ()) {
        let toUser = getUser(to)
        if toUser == nil || currentUser() == nil {
            return
        }
        if let imageData = UIImageJPEGRepresentation(image, 0.5) {
            let meta = StorageMetadata()
            meta.contentType = "image/jpeg"
            self.storageRef.child(generateUDID()).putData(imageData, metadata: meta, completion: { metadata, error in
                if error != nil {
                    result(error as NSError?)
                } else {
                    let ref = Database.database().reference()
                    let dateStr = self.dateFormatter.string(from: Date())
                    let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                                    "to" : to,
                                                    "image" : metadata!.path!,
                                                    "date" : dateStr]
                    ref.child("messages").childByAutoId().setValue(messageItem)
                    self.messagePush("\(currentUser()!.name!) sent photo.", to: toUser!, from: currentUser()!)
                    result(nil)
                }
            })
        }
    }
    
    func sendLocationMessage(_ coordinate:CLLocationCoordinate2D, to:String) {
        let ref = Database.database().reference()
        let dateStr = dateFormatter.string(from: Date())
        let messageItem:[String:Any] = ["from" : currentUser()!.uid!,
                                        "to" : to,
                                        "date" : dateStr,
                                        "latitude" : coordinate.latitude,
                                        "longitude" : coordinate.longitude]
        ref.child("messages").childByAutoId().setValue(messageItem)
        if let toUser = getUser(to) {
            self.messagePush("\(currentUser()!.name!) sent location.", to: toUser, from: currentUser()!)
        }
    }

    private func observeMessages() {
        let ref = Database.database().reference()
        let messageQuery = ref.child("messages").queryLimited(toLast:25)
        
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            let messageData = snapshot.value as! [String:Any]
            if let from = messageData["from"] as? String, let to = messageData["to"] as? String {
                if currentUser() != nil && self.getMessage(snapshot.key) == nil {
                    let received = (to == currentUser()!.uid!)
                    let sended = (from == currentUser()!.uid!)
                    if received || sended {
                        let message = self.createMessage(snapshot.key)
                        message.setData(messageData, new: received, completion: {
                            NotificationCenter.default.post(name: newMessageNotification, object: message)
                        })
                    }
                }
            } else {
                print("Error! Could not decode message data \(messageData)")
            }
        })
        
        deleteMessageRefHandle = messageQuery.observe(.childRemoved, with: { (snapshot) -> Void in
            if let message = self.getMessage(snapshot.key) {
                NotificationCenter.default.post(name: deleteMessageNotification, object: message)
                self.managedObjectContext.delete(message)
                self.saveContext()
            }
        })
    }
    
    func refreshMessages() {
        let ref = Database.database().reference()
        ref.child("messages").queryOrdered(byChild: "date").observeSingleEvent(of: .value, with: { snapshot in
            if let values = snapshot.value as? [String:Any] {
                for (key, value) in values {
                    let messageData = value as! [String:Any]
                    if let from = messageData["from"] as? String, let to = messageData["to"] as? String {
                        if currentUser() != nil && self.getMessage(snapshot.key) == nil {
                            let received = (to == currentUser()!.uid!)
                            let sended = (from == currentUser()!.uid!)
                            if received || sended {
                                let message = self.createMessage(key)
                                message.setData(messageData, new: false, completion: {
                                    NotificationCenter.default.post(name: newMessageNotification, object: message)
                                })
                            }
                        }
                    } else {
                        print("Error! Could not decode message data \(messageData)")
                    }
                }
            }
        })
    }

}

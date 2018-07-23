//
//  PushManager.swift
//  v-Space
//
//  Created by Сергей Сейтов on 22.10.2017.
//  Copyright © 2017 Сергей Сейтов. All rights reserved.
//

import UIKit
import AFNetworking
import Firebase

class PushManager: NSObject {
    static let shared = PushManager()

    private override init() {
        super.init()
    }
    
    fileprivate lazy var httpManager:AFHTTPSessionManager = {
        let manager = AFHTTPSessionManager(baseURL: URL(string: "https://fcm.googleapis.com/fcm/"))
        manager.requestSerializer = AFJSONRequestSerializer()
        manager.requestSerializer.setValue("application/json", forHTTPHeaderField: "Content-Type")
        manager.requestSerializer.setValue("key=\(pushServerKey)", forHTTPHeaderField: "Authorization")
        manager.responseSerializer = AFHTTPResponseSerializer()
        return manager
    }()

    func contactRequest(to:AppUser, success: @escaping(Bool) -> ()) {
        Model.shared.userToken(to, token: { token in
            if token != nil {
                let notification:[String:Any] = [
                    "title" : "v-Channel request",
                    "body" :"\(currentUser()!.name!) ask you to add him into contact list",
                    "sound":"default",
                    "content_available": true]
                let message:[String:Any] = ["to": token!, "priority": "high", "notification": notification]
                self.httpManager.post("send", parameters: message, progress: nil, success: { task, response in
                    success(true)
                }, failure: { task, error in
                    success(false)
                })
            } else {
                success(false)
            }
        })
    }
    
    func messagePush(_ text:String, to:AppUser, from:AppUser) {
        Model.shared.userToken(to, token: { token in
            if token != nil {
                let data:[String:Int] = ["pushType" : PushType.newMessage.rawValue]
                let notification:[String:Any] = [
                    "title" : "New message from \(from.name!):",
                    "body": text,
                    "sound":"default",
                    "content_available": true]
                let message:[String:Any] = ["to" : token!, "priority" : "high", "notification" : notification, "data" : data]
                self.httpManager.post("send", parameters: message, progress: nil, success: { task, response in
                }, failure: { task, error in
                    print("SEND PUSH ERROR: \(error)")
                })
            } else {
                print("USER HAVE NO TOKEN")
            }
        })
    }

    func pushCommand(to:String, command:String, success: @escaping(Bool) -> ()) {
/*
        Model.shared.userEndpoint(to, endpoint: { point in
            if point != nil {
                let message = AWSSNSPublishInput()
                message?.targetArn = point!
                message?.message = command
                AWSSNS.default().publish(message!).continueOnSuccessWith(executor: AWSExecutor.mainThread(), block: { task in
                    if task.error != nil {
                        print(task.error!.localizedDescription)
                    }
                    success(true)
                    return nil
                })
            } else {
                success(false)
            }
        })
 */
    }
    
    func callRequest(_ callID:String, to:String, success: @escaping(Bool) -> ()) {
/*
        Model.shared.userEndpoint(to, endpoint: { point in
            if point != nil {
                let message = AWSSNSPublishInput()
                message?.targetArn = point!
                let name = Auth.auth().currentUser!.displayName != nil ? Auth.auth().currentUser!.displayName! : "anonymous"
                let request = ["callID" : callID, "userID" : Auth.auth().currentUser!.uid, "userName" : name]
                if let data = try? JSONSerialization.data(withJSONObject: request, options: []) {
                    message?.message = String(data: data, encoding:.utf8)
                    AWSSNS.default().publish(message!).continueWith(block: { task in
                        DispatchQueue.main.async {
                            if task.error != nil {
                                print(task.error!.localizedDescription)
                                success(false)
                            } else {
                                success(true)
                            }
                        }
                        return nil
                    })
                } else {
                    success(false)
                }
            } else {
                success(false)
            }
        })
 */
    }
}

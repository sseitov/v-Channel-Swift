//
//  AppDelegate.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import Firebase
import UserNotifications
import GoogleMaps
import GoogleSignIn
import FBSDKLoginKit
import IQKeyboardManager
import SVProgressHUD
import PushKit
import AWSCognito
import AWSSNS

func IS_PAD() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

func MainApp() -> AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
}

func ShowCall(userName:String?, userID:String?, callID:String?) {
    let call = UIStoryboard(name: "Call", bundle: nil)
    if let nav = call.instantiateViewController(withIdentifier: "Call") as? UINavigationController {
        nav.modalTransitionStyle = .flipHorizontal
        if let top = MainApp().window?.rootViewController {
            if let callController = nav.topViewController as? CallController {
                callController.userName = userName
                callController.callID = callID
                callController.userID = userID
            }
            top.present(nav, animated: true, completion: nil)
            
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    var providerDelegate: ProviderDelegate!
    let callManager = CallManager()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    
        // Initialize SSL Peer Connection
        RTCInitializeSSL()

        // Use Firebase library to configure APIs
        FirebaseApp.configure()

        // Register_for_notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            
            guard error == nil else {
                //Display Error.. Handle Error.. etc..
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    //register for voip notifications
                    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
                    voipRegistry.desiredPushTypes = Set([.voIP])
                    voipRegistry.delegate = self;
                    
                    //Register for RemoteNotifications. Your Remote Notifications can display alerts now :)
                    application.registerForRemoteNotifications()
                }
            }
            else {
                //Handle user denying permissions..
            }
        }
        
        Messaging.messaging().delegate = self

        // Initialize Google Maps
        GMSServices.provideAPIKey(GoolgleMapAPIKey)

        // UI Customization
        UIApplication.shared.statusBarStyle = .lightContent
        
        SVProgressHUD.setDefaultStyle(.custom)
        SVProgressHUD.setBackgroundColor(MainColor)
        SVProgressHUD.setForegroundColor(UIColor.white)
        
        if let font = UIFont(name: "HelveticaNeue-CondensedBold", size: 17) {
            UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedStringKey.font : font], for: .normal)
            SVProgressHUD.setFont(font)
        }
        
        IQKeyboardManager.shared().isEnableAutoToolbar = false
        Camera.shared().startup()
        
        // Initialize the Amazon Cognito credentials provider
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast1,
                                                                identityPoolId:identityPoolID)
        let configuration = AWSServiceConfiguration(region:.USEast1, credentialsProvider:credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        providerDelegate = ProviderDelegate(callManager: callManager)

        return true
    }
    
    // MARK: - Application delegate
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme! == FACEBOOK_SCHEME {
            return FBSDKApplicationDelegate.sharedInstance().application(app, open: url, options: options)
        } else {
            return GIDSignIn.sharedInstance().handle(url,
                                                     sourceApplication: options[.sourceApplication] as! String?,
                                                     annotation: options[.annotation])
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
            Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        #else
            Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        #endif
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }
    
    func closeCall() {
        providerDelegate.closeIncomingCall()
    }
}

// MARK: - NotificationCenter delegate

@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        center.removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = -1
        let nav = window!.rootViewController as! UINavigationController
        nav.popToRootViewController(animated: false)
    }
}

extension AppDelegate : MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        Messaging.messaging().shouldEstablishDirectChannel = true
        if let currUser = currentUser() {
            Model.shared.publishToken(currUser, token: fcmToken)
        } else {
            UserDefaults.standard.set(fcmToken, forKey: "fcmToken")
        }
    }
    
}

// MARK: - PKPushRegistry delegate

extension AppDelegate : PKPushRegistryDelegate {
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let sns = AWSSNS.default()
        let endpointRequest = AWSSNSCreatePlatformEndpointInput()
        #if DEBUG
            endpointRequest?.platformApplicationArn = endpointDev
        #else
            endpointRequest?.platformApplicationArn = endpointProd
        #endif

        endpointRequest?.token = pushCredentials.token.hexadecimalString
        sns.createPlatformEndpoint(endpointRequest!).continueWith(executor: AWSExecutor.mainThread(), block: { task in
            if let response = task.result, let endpoint = response.endpointArn {
                if let currUser = currentUser() {
                    Model.shared.publishEndpoint(currUser, endpoint: endpoint)
                } else {
                    UserDefaults.standard.set(endpoint, forKey: "endpoint")
                }
            }
            return nil
        })

    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("token invalidated")
    }
    
    private func processPayload(_ payload: PKPushPayload, complete: @escaping () -> Void) {
        if let payloadDict = payload.dictionaryPayload["aps"] as? Dictionary<String, String>,
            let message = payloadDict["alert"]
        {
            if message == "hangup" {
                if UIApplication.shared.applicationState == .active {
                    NotificationCenter.default.post(name: hangUpCallNotification, object: nil)
                } else {
                    providerDelegate.closeIncomingCall()
                }
                complete()
            } else if message == "accept" {
                if UIApplication.shared.applicationState == .active {
                    NotificationCenter.default.post(name: acceptCallNotification, object: nil)
                }
                complete()
            } else {
                if let data = message.data(using: .utf8), let request = try? JSONSerialization.jsonObject(with: data, options: []), let requestData = request as? [String:Any]
                {
                    if let userName = requestData["userName"] as? String,
                        let userID = requestData["userID"] as? String,
                        let callID = requestData["callID"] as? String
                    {
                        if UIApplication.shared.applicationState == .active {
                            MainApp().window?.topMostController?.yesNoQuestion("\(userName) call you.", acceptLabel: "Accept", cancelLabel: "Reject", acceptHandler:
                                {
                                    SVProgressHUD.show()
                                    PushManager.shared.pushCommand(to: userID, command:"accept", success: { result in
                                        SVProgressHUD.dismiss()
                                        if !result {
                                            MainApp().window?.topMostController?.showMessage(LOCALIZE("requestError"), messageType: .error)
                                        } else {
                                            ShowCall(userName: userName, userID: userID, callID: callID)
                                        }
                                        complete()
                                    })
                            }, cancelHandler: {
                                PushManager.shared.pushCommand(to: userID, command: "hangup", success: { _ in
                                    complete()
                                })
                            })
                            
                        } else {
                            providerDelegate.reportIncomingCall(callID: callID,
                                                                userName: userName,
                                                                userID: userID, completion:
                                { error in
                                    if error != nil {
                                        print(error!.localizedDescription)
                                    }
                                    complete()
                            })
                        }
                    } else {
                        complete()
                    }
                } else {
                    complete()
                }
            }
        } else {
            complete()
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        processPayload(payload, complete: {
        })
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void)
    {
        processPayload(payload, complete: {
            completion()
        })
    }

}

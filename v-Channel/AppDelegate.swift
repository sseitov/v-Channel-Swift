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
                                                     sourceApplication: options[.sourceApplication] as! String!,
                                                     annotation: options[.annotation])
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if application.applicationState != .active {
            if let pushTypeStr = userInfo["pushType"] as? String, let pushType = Int(pushTypeStr) {
                if pushType == PushType.incommingCall.rawValue {
                    Ringtone.shared.play()
                } else if pushType == PushType.hangUpCall.rawValue {
                    Ringtone.shared.stop()
                }
            }
        }
        completionHandler(.newData)
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
        Ringtone.shared.stop()
        let nav = window!.rootViewController as! UINavigationController
        nav.popToRootViewController(animated: false)
    }
}

extension AppDelegate : MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        Messaging.messaging().shouldEstablishDirectChannel = true
        if let currUser = currentUser() {
            currUser.token = fcmToken
            Model.shared.publishToken(currUser, token: fcmToken)
        }
    }
    
}

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
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        let payloadDict = payload.dictionaryPayload["aps"] as? Dictionary<String, String>
        let message = payloadDict?["alert"]
        if UIApplication.shared.applicationState == .background {
            providerDelegate.reportIncomingCall(uuid: UUID(), handle: message!, hasVideo: false, completion: { error in
                if error != nil {
                    print(error!.localizedDescription)
                }
            })
        }
    }
}

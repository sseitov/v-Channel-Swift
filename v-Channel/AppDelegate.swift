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

func IS_PAD() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

func MainApp() -> AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
}

var bgTask:UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

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
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
/*
        if let command = userInfo["command"] as? String, command == "askLocaton" {
            if application.applicationState == .active {
                sendCurrentLocation {
                    completionHandler(.newData)
                }
            } else {
                bgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = UIBackgroundTaskInvalid
                })
                sendCurrentLocation {
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = UIBackgroundTaskInvalid
                    completionHandler(.newData)
                }
            }
        } else {
            completionHandler(.newData)
        }
 */
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        
        let token = tokenParts.joined()
        print("=========== Device Token: \(token)")

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
/*
        if let command = notification.request.content.userInfo["command"] as? String, command == "invite" {
            acceptInvite(notification.request.content.userInfo)
        }
 */
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
/*
        if let command = response.notification.request.content.userInfo["command"] as? String, command == "invite" {
            acceptInvite(response.notification.request.content.userInfo)
        }
        completionHandler()
*/
/*
        center.removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = -1
        let nav = window!.rootViewController as! UINavigationController
        nav.popToRootViewController(animated: false)
 */
    }
}

extension AppDelegate : MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        Messaging.messaging().shouldEstablishDirectChannel = true
        if let currUser = currentUser() {
            Model.shared.publishToken(currUser, token: fcmToken)
        } else {
            UserDefaults.standard.set(fcmToken, forKey: "fcmToken")
        }
    }
    
}

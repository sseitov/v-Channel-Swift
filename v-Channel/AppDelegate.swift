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

func IS_PAD() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // Register_for_notifications
        if #available(iOS 10.0, *) {
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
            
            UNUserNotificationCenter.current().delegate = self
            FIRMessaging.messaging().remoteMessageDelegate = self
            
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        application.registerForRemoteNotifications()
        
        // Use Firebase library to configure APIs
        FIRApp.configure()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.tokenRefreshNotification),
                                               name: .firInstanceIDTokenRefresh,
                                               object: nil)
        
        FIRAuth.auth()?.addStateDidChangeListener({ auth, user in
            if let token = FIRInstanceID.instanceID().token(), let currUser = auth.currentUser {
                Model.shared.publishToken(currUser, token:token)
            }
        })
        
        // Initialize Google Maps
        GMSServices.provideAPIKey(GoolgleMapAPIKey)
        
        //provideAPIKey(GoolgleMapAPIKey)

        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
                
        UIApplication.shared.statusBarStyle = .lightContent
        
        SVProgressHUD.setDefaultStyle(.custom)
        SVProgressHUD.setBackgroundColor(UIColor.mainColor())
        SVProgressHUD.setForegroundColor(UIColor.white)
        
        if let font = UIFont(name: "HelveticaNeue-CondensedBold", size: 17) {
            UIBarButtonItem.appearance().setTitleTextAttributes([NSFontAttributeName : font], for: .normal)
            SVProgressHUD.setFont(font)
        }
        IQKeyboardManager.shared().isEnableAutoToolbar = false
        
        return true
    }
    
    // MARK: - Refresh FCM token
    
    func tokenRefreshNotification(_ notification: Notification) {
        if let refreshedToken = FIRInstanceID.instanceID().token() {
            print("InstanceID token: \(refreshedToken)")
            connectToFcm()
            if let user = FIRAuth.auth()?.currentUser {
                Model.shared.publishToken(user, token: refreshedToken)
            } else {
                UserDefaults.standard.set(refreshedToken, forKey: "fcmToken")
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    func connectToFcm() {
        FIRMessaging.messaging().connect { (error) in
            if error != nil {
                print("Unable to connect with FCM. \(error)")
            }
        }
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
            FIRInstanceID.instanceID().setAPNSToken(deviceToken, type: FIRInstanceIDAPNSTokenType.sandbox)
        #else
            FIRInstanceID.instanceID().setAPNSToken(deviceToken, type: FIRInstanceIDAPNSTokenType.prod)
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

    // MARK: - SplitView delegate
    
    func splitViewController(_ svc: UISplitViewController, shouldHide vc: UIViewController, in orientation: UIInterfaceOrientation) -> Bool {
        return false
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, showDetail vc: UIViewController, sender: Any?) -> Bool {
        if splitViewController.isCollapsed {
            var secondViewController:UIViewController? = vc as? UINavigationController
            if secondViewController != nil {
                secondViewController = (secondViewController as! UINavigationController).topViewController
            } else {
                secondViewController = vc
            }
            
            if let master = splitViewController.viewControllers[0] as? UINavigationController {
                master.pushViewController(secondViewController!, animated: true)
            }
            return true
        } else {
            return false
        }
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
    }
}

extension AppDelegate : FIRMessagingDelegate {
    // Receive data message on iOS 10 devices while app is in the foreground.
    func applicationReceivedRemoteMessage(_ remoteMessage: FIRMessagingRemoteMessage) {
    }
}

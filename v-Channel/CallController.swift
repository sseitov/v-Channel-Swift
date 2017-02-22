//
//  CallController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import AVFoundation

protocol CallControllerDelegate {
    func callDidFinish(_ call:CallController)
}

class CallController: UIViewController {
    
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var loudButton: UIBarButtonItem!
    
    var delegate:CallControllerDelegate?
    var gateway:CallGatewayInfo?
    var contact:User?
    var incommingCall:[String:Any]?
    var incommingCallID:String?
    
    private var ringPlayer:AVAudioPlayer?
    private var busyPlayer:AVAudioPlayer?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if delegate == nil {
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = nil
            return
        } else {
            setupBackButton()
        }
        
        if contact == nil {
            contact = Model.shared.getUser(incommingCall!["from"] as! String)
            gateway = CallGatewayInfo(ip: incommingCall!["ip"] as! String, port: incommingCall!["port"] as! String)
            self.userImage.image = UIImage(data: self.contact!.avatar as! Data)?.withSize(self.userImage.frame.size).inCircle()
        } else {
            ringPlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "calling", withExtension: "wav")!)
            ringPlayer?.numberOfLoops = -1
            
            busyPlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "busy", withExtension: "wav")!)
            busyPlayer?.numberOfLoops = -1
            
            var gifs:[UIImage] = []
            for i in 0..<24 {
                gifs.append(UIImage(named: "ring_frame_\(i).gif")!)
            }
            userImage.animationImages = gifs
            userImage.animationDuration = 2
            userImage.animationRepeatCount = 0
            userImage.startAnimating()
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(self.hangUpCall(_:)),
                                                   name: hangUpCallNotification,
                                                   object: nil)
        }
        
        setupTitle(contact!.name!)
        
        VoipStreamHandler.sharedInstance().open(withGateway: gateway, receiverCount: 1, senderId: 0, silenceSuppression: 24)
        loudButton.image = VoipStreamHandler.sharedInstance().isLoudSpeaker() ?
            UIImage(named: "loudOn") : UIImage(named: "loudOff")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if delegate == nil {
            return
        }

        VoipStreamHandler.sharedInstance().startVoIP()
        if incommingCall != nil {
            VoipStreamHandler.sharedInstance().wait(forFinish: {
                self.incommingCall = nil
                self.goBack()
            })
        } else {
            incommingCallID = Model.shared.makeCall(to: contact!, ip: gateway!.publicIP!, port: gateway!.publicPort!)
            if ringPlayer != nil && ringPlayer!.prepareToPlay() {
                ringPlayer?.play()
            }
            VoipStreamHandler.sharedInstance().wait(forStart: {
                self.ringPlayer?.stop()
                self.userImage.stopAnimating()
                self.userImage.image = UIImage(data: self.contact!.avatar as! Data)?.withSize(self.userImage.frame.size).inCircle()
                VoipStreamHandler.sharedInstance().wait(forFinish: {
                    if self.incommingCallID != nil {
                        Model.shared.hangUpCall(callID: self.incommingCallID!)
                        self.incommingCallID = nil
                    }
                    self.goBack()
                })
            })
        }
    }
    
    override func goBack() {
        if delegate == nil {
            return
        }
        if incommingCall != nil || incommingCallID != nil {
            let alert = createQuestion("Want you hang up?", acceptTitle: "Yes", cancelTitle: "Cancel", acceptHandler: {
                self.ringPlayer?.stop()
                VoipStreamHandler.sharedInstance().hangUp()
                if self.incommingCallID != nil {
                    Model.shared.hangUpCall(callID: self.incommingCallID!)
                    self.incommingCallID = nil
                }
                self.delegate?.callDidFinish(self)
            })
            alert?.show()
        } else {
            self.busyPlayer?.stop()
            VoipStreamHandler.sharedInstance().hangUp()
            self.delegate?.callDidFinish(self)
        }
    }
    
    func hangUpCall(_ notify:Notification) {
        if let callID = notify.object as? String {
            if (self.incommingCallID != nil && self.incommingCallID! == callID) {
                self.self.incommingCallID = nil
                self.ringPlayer?.stop()
                self.userImage.stopAnimating()
                self.userImage.image = UIImage(named: "logo.png")
                if self.busyPlayer!.prepareToPlay() {
                    self.busyPlayer?.play()
                }
            }
        }
    }
    
    @IBAction func switchLoud(_ sender: UIBarButtonItem) {
        var isLoud = VoipStreamHandler.sharedInstance().isLoudSpeaker()
        isLoud = !isLoud
        VoipStreamHandler.sharedInstance().enableLoudspeaker(isLoud)
        sender.image = VoipStreamHandler.sharedInstance().isLoudSpeaker() ?
            UIImage(named: "loudOn") : UIImage(named: "loudOff")
    }

}

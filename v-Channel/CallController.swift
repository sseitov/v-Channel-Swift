//
//  CallController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import AVFoundation
import MPMessagePack

protocol CallControllerDelegate {
    func callDidFinish(_ call:CallController)
}

class CallController: UIViewController {
    
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var videoView: UIView!
    
    var delegate:CallControllerDelegate?
    var audioGateway:CallGatewayInfo?
    var videoGateway:CallGatewayInfo?
    var contact:User?
    var incommingCall:[String:Any]?
    var incommingCallID:String?
    
    private var ringPlayer:AVAudioPlayer?
    private var busyPlayer:AVAudioPlayer?
    private var videoController:VideoController?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoView.isHidden = true
        if delegate == nil {
            navigationItem.leftBarButtonItem = nil
            return
        } else {
            setupBackButton()
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.hangUpCall(_:)),
                                               name: hangUpCallNotification,
                                               object: nil)
        
        if contact == nil {
            contact = Model.shared.getUser(incommingCall!["from"] as! String)
            audioGateway = CallGatewayInfo(ip: incommingCall!["audioIP"] as! String, port: incommingCall!["audioPort"] as! String)
            videoGateway = CallGatewayInfo(ip: incommingCall!["videoIP"] as! String, port: incommingCall!["videoPort"] as! String)
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
                                                   selector: #selector(self.acceptCall(_:)),
                                                   name: acceptCallNotification,
                                                   object: nil)
        }
        
        setupTitle(contact!.name!)
        
        VoipStreamHandler.sharedInstance().open(withGateway: audioGateway, videoGateway: videoGateway, receiverCount: 1, senderId: 0, silenceSuppression: 24);
    }
    
    private func rightButtonItems() -> [UIBarButtonItem] {
        let loudImage = VoipStreamHandler.sharedInstance().isLoudSpeaker() ? UIImage(named: "loudOn") : UIImage(named: "loudOff")
        let sound = UIBarButtonItem(image: loudImage, style: .plain, target: self, action: #selector(self.switchLoud(_:)))
        sound.tintColor = UIColor.white
        let video = UIBarButtonItem(image: UIImage(named: "videoOff"), style: .plain, target: self, action: #selector(self.switchVideo(_:)))
        video.tintColor = UIColor.white
        return [video, sound]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if delegate == nil {
            return
        }

        if incommingCall != nil {
            startCall()
            navigationItem.setRightBarButtonItems(rightButtonItems(), animated: true)
        } else {
            incommingCallID = Model.shared.makeCall(to: contact!,
                                                    audioIP: audioGateway!.publicIP!,
                                                    audioPort: audioGateway!.publicPort!,
                                                    videoIP: videoGateway!.publicIP!,
                                                    videoPort: videoGateway!.publicPort!)
            if ringPlayer != nil && ringPlayer!.prepareToPlay() {
                ringPlayer?.play()
            }
        }
    }
    
    override func goBack() {
        if delegate == nil {
            return
        }
        
        if busyPlayer != nil && busyPlayer!.isPlaying {
            self.busyPlayer?.stop()
            Model.shared.hangUpCall(self.incommingCallID!)
            self.incommingCallID = nil
            self.delegate?.callDidFinish(self)
        } else if incommingCall != nil || incommingCallID != nil {
            let callID = incommingCallID != nil ? incommingCallID : incommingCall!["uid"] as? String
            let alert = createQuestion("Want you hang up?", acceptTitle: "Yes", cancelTitle: "Cancel", acceptHandler: {
                Model.shared.hangUpCall(callID!)
                self.finishCall()
                self.delegate?.callDidFinish(self)
            })
            alert?.show()
        } else {
            self.delegate?.callDidFinish(self)
        }
    }
    
    private func startCall() {
        VoipStreamHandler.sharedInstance().startVoIP()
        VoipStreamHandler.sharedInstance().startVideo({ data in
            if data != nil {
                if let dictionary = try? (data! as NSData).mp_dict(), let messageType = dictionary["type"] as? String {
                    if messageType == "frame" {
                        self.videoController?.receiveVideoMessage(CallVideoFrameMessage(dictionary: dictionary))
                    } else if messageType == "start" {
                        self.videoController?.receiveVideoMessage(CallVideoStartMessage(dictionary: dictionary))
                    } else if messageType == "accept" {
                        self.videoController?.receiveVideoMessage(CallVideoAcceptMessage())
                    } else if messageType == "stop" {
                        self.videoController?.receiveVideoMessage(CallVideoStopMessage())
                    }
                } else {
                    print("invalid data")
                }
            }
        })
    }
    
    private func finishCall() {
        self.incommingCallID = nil
        self.incommingCall = nil
        self.ringPlayer?.stop()
        self.busyPlayer?.stop()
        VoipStreamHandler.sharedInstance().hangUp()
        if !self.videoView.isHidden {
            self.videoController!.shutdown()
        }
    }
    
    func acceptCall(_ notify:Notification) {
        if let callID = notify.object as? String, callID == incommingCallID!, notify.userInfo != nil, let accept = notify.userInfo!["accept"] as? Bool {
            self.ringPlayer?.stop()
            self.userImage.stopAnimating()
            if accept {
                self.navigationItem.setRightBarButtonItems(self.rightButtonItems(), animated: true)
                self.userImage.image = UIImage(data: self.contact!.avatar as! Data)?.withSize(self.userImage.frame.size).inCircle()
                startCall()
            } else {
                self.busyPlayer?.play()
                VoipStreamHandler.sharedInstance().hangUp()
            }
        }
    }
    
    func hangUpCall(_ notify:Notification) {
        if incommingCall != nil || incommingCallID != nil {
            let selfCallID = incommingCallID != nil ? incommingCallID : incommingCall!["uid"] as? String
            if let callID = notify.object as? String, callID == selfCallID {
                self.finishCall()
                self.delegate?.callDidFinish(self)
            }
        }
    }
    
    func switchLoud(_ sender: UIBarButtonItem) {
        var isLoud = VoipStreamHandler.sharedInstance().isLoudSpeaker()
        isLoud = !isLoud
        VoipStreamHandler.sharedInstance().enableLoudspeaker(isLoud)
        sender.image = VoipStreamHandler.sharedInstance().isLoudSpeaker() ?
            UIImage(named: "loudOn") : UIImage(named: "loudOff")
    }

    func switchVideo(_ sender: UIBarButtonItem) {
        videoView.isHidden = !videoView.isHidden
        sender.image = videoView.isHidden ? UIImage(named: "videoOff") : UIImage(named: "videoOn")
        if videoController != nil {
            if videoView.isHidden {
                VoipStreamHandler.sharedInstance().sendVideoMessage(CallVideoStopMessage())
                videoController!.shutdown()
            } else {
                videoController?.peerView.image = userImage.image
                videoController!.start()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "videoView" {
            videoController = segue.destination as? VideoController
            videoController?.delegate = self
        }
    }
    
}

extension CallController : VideoControllerDelegate {
    
    func sendVideoMessage(_ message: CallMessage!) {
        VoipStreamHandler.sharedInstance().sendVideoMessage(message)
    }
    
}

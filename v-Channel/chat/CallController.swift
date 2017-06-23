//
//  CallController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 27.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

class CallController: UIViewController {
    
    var user:AppUser?
    var incommingCall:String?

    @IBOutlet weak var callView: UIView!
    @IBOutlet weak var callImage: UIImageView!
    @IBOutlet weak var remoteView: RTCEAGLVideoView!
    @IBOutlet weak var localView: RTCEAGLVideoView!
    
    private var ringPlayer:AVAudioPlayer?
    private var busyPlayer:AVAudioPlayer?
    private var loudOn = true
    private var videoOn = true
    
    var observerContext = 0
    
    var rtcClient:ARDAppClient?
    var localVideoTrack:RTCVideoTrack?
    var remoteVideoTrack:RTCVideoTrack?
    var captureController:ARDCaptureController?
    
    var localAspect:CGFloat = 1
    var remoteAspect:CGFloat = 1
    var remoteSize:CGSize = CGSize()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        setupTitle(user!.name!)
        
        if incommingCall == nil {
            incommingCall = Model.shared.makeCall(to: user!)
            ringPlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "calling", withExtension: "wav")!)
            ringPlayer?.numberOfLoops = -1
            ringPlayer!.prepareToPlay()
            ringPlayer?.play()
            
            var gifs:[UIImage] = []
            for i in 0..<24 {
                gifs.append(UIImage(named: "ring_frame_\(i).gif")!)
            }
            callImage.animationImages = gifs
            callImage.animationDuration = 2
            callImage.animationRepeatCount = 0
            callImage.startAnimating()
            
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(self.acceptCall(_:)),
                                                   name: acceptCallNotification,
                                                   object: nil)
        } else {
            connect()
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.hangUpCall(_:)),
                                               name: hangUpCallNotification,
                                               object: nil)
    }

    func connect() {
        remoteView.delegate = self
        localView.delegate = self
        rtcClient = ARDAppClient(delegate: self)
        let settings = ARDSettingsModel()
        rtcClient?.connectToRoom(withId: incommingCall,
                                 settings: settings,
                                 isLoopback: false,
                                 isAudioOnly: false,
                                 shouldMakeAecDump: false,
                                 shouldUseLevelControl: false)
        callView.isHidden = true
    }
    
    func disconnect() {
        localVideoTrack?.remove(localView)
        remoteVideoTrack?.remove(remoteView)
        localVideoTrack = nil
        remoteVideoTrack = nil
        captureController?.stopCapture()
        captureController = nil
        rtcClient?.disconnect()
        rtcClient = nil
        callView.isHidden = false
    }
    
    override func goBack() {
        if incommingCall != nil {
            yesNoQuestion("Want you hang up?", acceptLabel: "Yes", cancelLabel: "Cancel", acceptHandler: {
                Model.shared.hangUpCall(self.incommingCall!)
                if self.rtcClient != nil {
                    self.disconnect()
                    super.goBack()
                }
            })
        } else {
            if self.busyPlayer != nil {
                self.busyPlayer?.stop()
                self.busyPlayer = nil
                super.goBack()
            } else if self.rtcClient != nil {
                self.disconnect()
                super.goBack()
            }
        }
    }
    
    func acceptCall(_ notify:Notification) {
        if incommingCall != nil, let call = notify.object as? String, incommingCall! == call {
            self.ringPlayer?.stop()
            self.ringPlayer = nil
            self.callImage.stopAnimating()
            
            connect()
        }
    }
    
    func hangUpCall(_ notify:Notification) {
        if self.ringPlayer != nil {
            self.ringPlayer?.stop()
            self.ringPlayer = nil
            
            self.callImage.stopAnimating()
            self.callImage.image = self.user!.getImage().withSize(self.callImage.frame.size).inCircle()
            
            self.busyPlayer = try? AVAudioPlayer(contentsOf: Bundle.main.url(forResource: "busy", withExtension: "wav")!)
            self.busyPlayer?.numberOfLoops = -1
            self.busyPlayer!.prepareToPlay()
            self.busyPlayer?.play()
            incommingCall = nil
        } else {
            if incommingCall != nil, let call = notify.object as? String, incommingCall! == call {
                incommingCall = nil
                goBack()
            }
        }
    }

    func updateRemoteSize() {
        let aspect = view.frame.size.width / view.frame.size.height
        let zoom = (aspect > 1) ? remoteSize.height / view.frame.size.height : remoteSize.width / view.frame.size.width
        if remoteAspect > 1 {
            let h = (remoteSize.width / remoteAspect) / zoom
            self.remoteView.frame = CGRect(x: 0, y: (self.view.frame.size.height - h) / 2, width: self.view.frame.size.width, height: h)
        } else {
            let w = (remoteSize.height * remoteAspect) / zoom
            self.remoteView.frame = CGRect(x: (self.view.frame.size.width - w) / 2 , y: 0, width: w, height: self.view.frame.size.height)
        }
    }
    
    func updateLocalSize() {
        let org = CGPoint(x: self.view.frame.size.width - 140, y: self.view.frame.size.height - 140)
        if localAspect > 1 {
            let h = 120 / localAspect
            self.localView.frame = CGRect(x: org.x, y: org.y + (120 - h) / 2, width: 120, height: h)
        } else {
            let w = 120 * localAspect
            self.localView.frame = CGRect(x: org.x + (120 - w) / 2 , y: org.y, width: w, height: 120)
        }
    }
}

extension CallController : ARDAppClientDelegate {
    
    func appClient(_ client: ARDAppClient!, didError error: Error!) {
        DispatchQueue.main.async {
            self.showMessage("Error: \(error.localizedDescription)", messageType: .error, messageHandler: {
                self.goBack()
            })
        }
    }

    func appClient(_ client: ARDAppClient!, didChange state: ARDAppClientState) {
        switch state {
        case .connecting:
            break
        case .connected:
            break
        case .disconnected:
            break
        }
    }
    
    func appClient(_ client: ARDAppClient!, didChange state: RTCIceConnectionState) {
        switch state {
        case .new:
            print("$$$$$ new")
        case .checking:
            print("$$$$$ checking")
        case .connected:
            print("$$$$$ connected")
        case .completed:
            print("$$$$$ completed")
        case .failed:
            print("$$$$$ failed")
        case .disconnected:
            print("$$$$$ disconnected")
        case .closed:
            print("$$$$$ closed")
        case .count:
            print("$$$$$ count")
        }
    }
    
    func appClient(_ client: ARDAppClient!, didGetStats stats: [Any]!) {
    }

    func appClient(_ client: ARDAppClient!, didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack!) {
        print("didReceiveLocalVideoTrack")
        self.localVideoTrack = localVideoTrack
        self.localVideoTrack?.add(self.localView)
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack!) {
        print("didReceiveRemoteVideoTrack")
        self.remoteVideoTrack = remoteVideoTrack
        self.remoteVideoTrack?.add(self.remoteView)
    }
    
    func appClient(_ client: ARDAppClient!, didCreateLocalCapturer localCapturer: RTCCameraVideoCapturer!) {
        print("didCreateLocalCapturer")
        captureController = ARDCaptureController(capturer: localCapturer, settings: ARDSettingsModel())
        captureController?.startCapture()
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveRemoteAudioTracks remoteAudioTrack: RTCAudioTrack!) {
        print("didReceiveRemoteAudioTracks")
    }

}

extension CallController : RTCEAGLVideoViewDelegate {
    
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
        let aspect = size.width / size.height
        if videoView == self.remoteView {
            self.remoteAspect = aspect
            self.remoteSize = size
            self.updateRemoteSize()
        } else if videoView == self.localView {
            self.localAspect = aspect
            self.updateLocalSize()
        }
    }
}


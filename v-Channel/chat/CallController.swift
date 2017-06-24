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
    @IBOutlet weak var localView: RTCCameraPreviewView!
    @IBOutlet weak var videoButton: UIBarButtonItem!
    @IBOutlet weak var loudButton: UIBarButtonItem!
    
    private var ringPlayer:AVAudioPlayer?
    private var busyPlayer:AVAudioPlayer?
    
    var isLoud = false {
        didSet {
            if isLoud {
                loudButton.image = UIImage(named: "loudOn")
            } else {
                loudButton.image = UIImage(named: "loudOff")
            }
        }
    }
    var isVideo = true {
        didSet {
            if isVideo {
                videoButton.image = UIImage(named: "videoOn")
            } else {
                videoButton.image = UIImage(named: "videoOff")
            }
        }
    }
    
    var rtcClient:ARDAppClient?
    var videoTrack:RTCVideoTrack?
    var videoSize:CGSize = CGSize()
    var cameraController:ARDCaptureController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        setupTitle(user!.name!)
  
        remoteView.delegate = self
        ARDAppClient.enableLoudspeaker(false)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.hangUpCall(_:)),
                                               name: hangUpCallNotification,
                                               object: nil)
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
        
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if localView.captureSession != nil {
            localView.setNeedsLayout()
        }
        if videoTrack != nil {
            updateVideoSize()
        }
    }
    
    func connect() {
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
        videoTrack?.remove(remoteView)
        videoTrack = nil
        remoteView.renderFrame(nil)
        
        localView.captureSession = nil
        cameraController?.stopCapture()
        cameraController = nil
        rtcClient?.disconnect()
        ARDAppClient.hangUp()
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

    func updateVideoSize() {
        if videoSize.width > 0 && videoSize.height > 0 {
            var remoteVideoFrame = AVMakeRect(aspectRatio: videoSize, insideRect: view.bounds)
            var scale:CGFloat = 1
            if (remoteVideoFrame.size.width > remoteVideoFrame.size.height) {
                // Scale by height.
                scale = view.bounds.size.height / remoteVideoFrame.size.height;
            } else {
                // Scale by width.
                scale = view.bounds.size.width / remoteVideoFrame.size.width;
            }
            remoteVideoFrame.size.height *= scale;
            remoteVideoFrame.size.width *= scale;
            remoteView.frame = remoteVideoFrame
            remoteView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }
    }
    
    @IBAction func muteVideo(_ sender: UIBarButtonItem) {
        if isVideo {
            cameraController?.stopCapture()
            isVideo = false
        } else {
            cameraController?.startCapture()
            isVideo = true
        }
    }
    
    @IBAction func switchSpeaker(_ sender: UIBarButtonItem) {
        ARDAppClient.enableLoudspeaker(!isLoud)
        isLoud = ARDAppClient.isLoudSpeaker()
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
    }
    
    func appClient(_ client: ARDAppClient!, didCreateLocalCapturer localCapturer: RTCCameraVideoCapturer!) {
        print("================== didCreateLocalCapturer \(Thread.current)")
        DispatchQueue.main.async {
            self.localView.captureSession = localCapturer.captureSession
            self.localView.setupBorder(UIColor.yellow, radius: 5, width: 2)
            self.cameraController = ARDCaptureController(capturer: localCapturer, settings: ARDSettingsModel())
            self.cameraController?.startCapture()
            self.isVideo = true
        }
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack!) {
        print("================== didReceiveRemoteVideoTrack \(Thread.current)")
        videoTrack = remoteVideoTrack
        videoTrack?.add(self.remoteView)
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveRemoteAudioTracks remoteAudioTrack: RTCAudioTrack!) {
        isLoud = ARDAppClient.isLoudSpeaker()
    }

}

extension CallController : RTCEAGLVideoViewDelegate {
    
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
        print("================== didChangeVideoSize \(Thread.current)")
        videoSize = size
        updateVideoSize()
    }
}


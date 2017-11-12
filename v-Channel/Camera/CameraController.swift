//
//  CameraController.swift
//
//  Created by Сергей Сейтов on 06.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import AudioToolbox
import SVProgressHUD

protocol CameraDelegate {
    func didTakePhoto(_ image:UIImage)
}

class CameraController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var videoLayer: VideoLayerView!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var buttonView: UIView!
    
    @IBOutlet weak var resultView: UIView!
    @IBOutlet weak var photoView: UIImageView!
    
    var delegate:CameraDelegate?
    var isFront = true
    
    private var active = true
    private var orientation:UIDeviceOrientation?
    private var pixelBuffer:CVImageBuffer?
    private let pixelBufferLock = NSLock()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        buttonView.setupBorder(UIColor.clear, radius: 40)
        
        orientation = UIDevice.current.orientation

        if isFront {
            if Camera.shared().isBack() {
                Camera.shared().switch()
            }
        } else {
            if !Camera.shared().isBack() {
                Camera.shared().switch()
            }
        }
        
        updateMode()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.orientationChanged(_:)),
                                               name: NSNotification.Name.UIDeviceOrientationDidChange,
                                               object: nil)
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapScreen))
        self.view.addGestureRecognizer(tap)
    }
    
    @objc func tapScreen() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @objc func orientationChanged(_ notify:Notification) {
        orientation = UIDevice.current.orientation
    }
    
    private func updateMode() {
        if active {
            resultView.isHidden = true
            leftButton.setTitle("Cancel", for: .normal)
            rightButton.isHidden = true
            Camera.shared().output.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        } else {
            resultView.isHidden = false
            leftButton.setTitle("Retake", for: .normal)
            rightButton.isHidden = false
            Camera.shared().output.setSampleBufferDelegate(nil, queue: DispatchQueue.global())
        }
        cameraButton.isEnabled = active
    }
    
    @IBAction func leftAction(_ sender: Any) {
        if active {
            dismiss(animated: true, completion: nil)
        } else {
            active = true
            updateMode()
        }
    }
    
    @IBAction func takePhoto(_ sender: Any) {
        AudioServicesPlaySystemSoundWithCompletion(1108, {
            DispatchQueue.main.async {
                self.photoView.image = self.getImage()
                self.active = false
                self.updateMode()
            }
        })
    }

    @IBAction func usePhoto(_ sender: Any) {
        delegate?.didTakePhoto(photoView.image!)
    }
    
    // MARK: - AVCaptureVideoDataOutput delegate
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        pixelBufferLock.lock()
        
        if connection.isVideoOrientationSupported && connection.videoOrientation.rawValue != orientation!.rawValue {
            connection.videoOrientation = AVCaptureVideoOrientation(rawValue: orientation!.rawValue)!
        }
        pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        videoLayer.draw(sampleBuffer)
        
        pixelBufferLock.unlock()
    }

    func getImage() -> UIImage? {
        pixelBufferLock.lock()
        if pixelBuffer == nil {
            pixelBufferLock.unlock()
            return nil
        }

        let ciImage = CIImage.init(cvImageBuffer: pixelBuffer!)
        let ciContext = CIContext()
        let width = CVPixelBufferGetWidth(pixelBuffer!)
        let height = CVPixelBufferGetHeight(pixelBuffer!)
        if let videoImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) {
            let image = UIImage(cgImage: videoImage)
            let photoFrame = videoLayer.centerRect()
            var rect:CGRect = CGRect()
            if width < height {
                let scale = CGFloat(width) / photoFrame.size.width
                rect = CGRect(x: photoFrame.origin.x*scale,
                              y: photoFrame.origin.y*scale,
                              width: CGFloat(width),
                              height: CGFloat(width))
            } else {
                let scale = CGFloat(height) / photoFrame.size.width
                rect = CGRect(x: photoFrame.origin.x*scale,
                              y: photoFrame.origin.y*scale,
                              width: CGFloat(height),
                              height: CGFloat(height))
            }
            pixelBufferLock.unlock()
            return image.partWithFrame(rect)
        } else {
            pixelBufferLock.unlock()
            return nil
        }
    }

}

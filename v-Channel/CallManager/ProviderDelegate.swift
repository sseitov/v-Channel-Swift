/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import CallKit
import AVFoundation

class ProviderDelegate: NSObject {
  
    fileprivate let callManager: CallManager
    fileprivate let provider: CXProvider
    fileprivate var rejected:Bool = true
    fileprivate var activeCall:Call?
    fileprivate var incommingCallID:String?
    fileprivate var incommingCall:[String:Any]?
    
  init(callManager: CallManager) {
    self.callManager = callManager
    provider = CXProvider(configuration: type(of: self).providerConfiguration)
    
    super.init()
    
    provider.setDelegate(self, queue: nil)
  }
    
  static var providerConfiguration: CXProviderConfiguration {
    let providerConfiguration = CXProviderConfiguration(localizedName: "v-Channel")
    
    providerConfiguration.supportsVideo = true
    providerConfiguration.maximumCallsPerCallGroup = 1
    providerConfiguration.maximumCallGroups = 1
    providerConfiguration.supportedHandleTypes = [.generic]
    if let image = UIImage(named: "stop") {
        providerConfiguration.iconTemplateImageData = UIImagePNGRepresentation(image)
    }
    return providerConfiguration
  }
  
  func reportIncomingCall(uuid: UUID, handle: String, completion: ((NSError?) -> Void)?) {
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: handle)
    update.hasVideo = true
    update.supportsHolding = false
    update.localizedCallerName = handle
    
    rejected = true
    provider.reportNewIncomingCall(with: uuid, update: update) { error in
      if error == nil {
        let call = Call(uuid: uuid, handle: handle)
        self.callManager.add(call: call)
      }
        
        Model.shared.incommingCall({ call in
            if call != nil {
                self.incommingCall = call
                self.incommingCallID = call?.keys.first
            }
        })

      completion?(error as NSError?)
    }
  }

    func closeIncomingCall() {
        if activeCall != nil {
            rejected = false
            callManager.end(call: activeCall!)
        }
    }
}

// MARK: - CXProviderDelegate

extension ProviderDelegate: CXProviderDelegate {
  func providerDidReset(_ provider: CXProvider) {

    for call in callManager.calls {
      call.end()
    }
    callManager.removeAllCalls()
  }
  
  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
      action.fail()
      return
    }
    activeCall = call
    call.answer()
    action.fulfill()
    let nav = MainApp().window?.rootViewController as? UINavigationController
    nav?.popToRootViewController(animated: false)
    if incommingCall != nil {
        Model.shared.acceptCall(incommingCallID!)
        ContactList()?.activateCall(incommingCall!)
    }
  }
  
  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
      action.fail()
      return
    }

    call.end()
    action.fulfill()
    callManager.remove(call: call)
    
    if rejected && incommingCallID != nil {
        Model.shared.hangUpCall(incommingCallID!)
    }
  }
  
  func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
    guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
      action.fail()
      return
    }
    
    call.state = action.isOnHold ? .held : .active
    action.fulfill()
  }
  
  func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    let call = Call(uuid: action.callUUID, outgoing: true, handle: action.handle.value)
    
    call.connectedStateChanged = { [weak self] in
      guard let strongSelf = self else { return }
      
      if case .pending = call.connectedState {
        strongSelf.provider.reportOutgoingCall(with: call.uuid, startedConnectingAt: nil)
      } else if case .complete = call.connectedState {
        strongSelf.provider.reportOutgoingCall(with: call.uuid, connectedAt: nil)
      }
    }
    
    call.start { [weak self] success in
      guard let strongSelf = self else { return }
      
      if success {
        action.fulfill()
        strongSelf.callManager.add(call: call)
      } else {
        action.fail()
      }
    }
  }
  
  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
  }
}

//
//  RingtonePlayer.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 06.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import AVFoundation

class Ringtone {
    
    static let shared = Ringtone()
    
    private var ringPlayer:AVAudioPlayer?
  
    private init() {
        createRingtone()
    }

    private func createRingtone() {
        var url = defaultRingtone()
        if url == nil {
            url = Bundle.main.url(forResource: "ringtone", withExtension: "wav")
        }
        ringPlayer = try? AVAudioPlayer(contentsOf: url!)
        ringPlayer?.numberOfLoops = -1
    }
    
    func defaultRingtone() -> URL? {
        return UserDefaults.standard.url(forKey: "ringtone")
    }
    
    func setDefaultRingtone(_ ringtone:URL?) {
        if ringtone == nil {
            UserDefaults.standard.removeObject(forKey: "ringtone")
        } else {
            UserDefaults.standard.set(ringtone, forKey: "ringtone")
        }
        UserDefaults.standard.synchronize()
        createRingtone()
    }
    
    func play() {
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with:[.mixWithOthers])
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        try? AVAudioSession.sharedInstance().setActive(true)

        if ringPlayer!.prepareToPlay() {
            ringPlayer!.play()
        }
    }
    
    func stop() {
        ringPlayer?.stop()
    }

}

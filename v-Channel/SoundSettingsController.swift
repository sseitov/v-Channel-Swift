//
//  SoundSettingsController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 22.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import AVFoundation

class SoundSettingsController: UITableViewController {

    private var systemRingtones:[URL] = []
    private var defaultSettings:URL?
    private var ringPlayer:AVAudioPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("Select ringtone")
        setupBackButton()
        defaultSettings = UserDefaults.standard.url(forKey: "ringtone")
        let enumerator = FileManager.default.enumerator(at: URL(string: "/Library/Ringtones")!, includingPropertiesForKeys: [.isDirectoryKey])
        while let url = enumerator?.nextObject() as? URL {
            systemRingtones.append(url)
        }
    }
    
    @IBAction func selectSound(_ sender: Any) {
        if defaultSettings == nil {
            UserDefaults.standard.removeObject(forKey: "ringtone")
        } else {
            UserDefaults.standard.set(defaultSettings, forKey: "ringtone")
        }
        UserDefaults.standard.synchronize()
        defaultSettings = UserDefaults.standard.url(forKey: "ringtone")
        goBack()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return systemRingtones.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "simplevoip ringtones"
        } else {
            return "system ringtones"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        if indexPath.section == 0{
            cell.textLabel?.text = "Default"
            if defaultSettings == nil {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        } else {
            let name = systemRingtones[indexPath.row].lastPathComponent
            let ext = systemRingtones[indexPath.row].pathExtension
            cell.textLabel?.text = name.replacingOccurrences(of: ".\(ext)", with: "")
            if defaultSettings != nil && defaultSettings! == systemRingtones[indexPath.row] {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }
        cell.selectionStyle = .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section == 0 {
            defaultSettings = nil
        } else {
            defaultSettings = systemRingtones[indexPath.row]
        }
        var selected = tableView.indexPathForSelectedRow
        if selected == nil {
            selected = IndexPath(row: 0, section: 0)
        }
        
        tableView.beginUpdates()
        tableView.reloadRows(at: [selected!, indexPath], with: .fade)
        tableView.endUpdates()
        
        return indexPath
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let url = indexPath.section == 0 ? Bundle.main.url(forResource: "ringtone", withExtension: "wav")! : systemRingtones[indexPath.row]
        ringPlayer = try? AVAudioPlayer(contentsOf: url)
        if ringPlayer!.prepareToPlay() {
            ringPlayer?.play()
        }
    }

}

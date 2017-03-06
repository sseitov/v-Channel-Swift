//
//  SoundSettingsController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 22.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit

class SoundSettingsController: UITableViewController {

    private var systemRingtones:[URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("Select ringtone")
        setupBackButton()
        let enumerator = FileManager.default.enumerator(at: URL(string: "/Library/Ringtones")!, includingPropertiesForKeys: [.isDirectoryKey])
        while let url = enumerator?.nextObject() as? URL {
            systemRingtones.append(url)
        }
        Ringtone.shared.play()
    }
    
    override func goBack() {
        Ringtone.shared.stop()
        super.goBack()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let url = Ringtone.shared.defaultRingtone(), let index = systemRingtones.index(of: url) {
            let indexPath = IndexPath(row: index, section: 1)
            
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
        }
        Ringtone.shared.play()
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
            if Ringtone.shared.defaultRingtone() == nil {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        } else {
            let name = systemRingtones[indexPath.row].lastPathComponent
            let ext = systemRingtones[indexPath.row].pathExtension
            cell.textLabel?.text = name.replacingOccurrences(of: ".\(ext)", with: "")
            if indexPath.section == 0 {
                if Ringtone.shared.defaultRingtone() == nil {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            } else {
                let ringtone = Ringtone.shared.defaultRingtone()
                if ringtone != nil && ringtone! == systemRingtones[indexPath.row] {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }
            }
        }
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.reloadData()
        let url:URL? = indexPath.section == 0 ? nil : systemRingtones[indexPath.row]
        Ringtone.shared.setDefaultRingtone(url)
        Ringtone.shared.play()
    }

}

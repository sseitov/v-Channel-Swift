//
//  SettingsController.swift
//  v-Channel
//
//  Created by Сергей Сейтов on 22.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import UIKit
import SVProgressHUD

class SettingsController: UITableViewController {

    var delegate:LoginControllerDelegate?
    
    private var defaultSoundSetting:URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle("My Profile")
        setupBackButton()
        defaultSoundSetting = UserDefaults.standard.url(forKey: "ringtone")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "account" : "settings"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.font = UIFont.condensedFont(17)
        cell.detailTextLabel?.font = UIFont.mainFont(15)
        if indexPath.section == 0 {
            cell.textLabel?.text = currentUser()!.email!
            cell.detailTextLabel?.text = "Sign Out"
        } else {
            cell.textLabel?.text = "Ringtone"
            if defaultSoundSetting == nil {
                cell.detailTextLabel?.text = "Default"
            } else {
                let name = defaultSoundSetting!.lastPathComponent
                let ext = defaultSoundSetting!.pathExtension
                cell.detailTextLabel?.text = name.replacingOccurrences(of: ".\(ext)", with: "")
            }
        }
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let alert = createQuestion("Are you sure you want to delete account?", acceptTitle: "Sure", cancelTitle: "Cancel", acceptHandler: {
                SVProgressHUD.show(withStatus: "SignOut...")
                Model.shared.signOut({
                    SVProgressHUD.dismiss()
                    self.delegate?.didLogout()
                })
            })
            alert?.show()
        } else {
            performSegue(withIdentifier: "selectRingtone", sender: nil)
        }
    }

}

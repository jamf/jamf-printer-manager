//
//  Copyright 2026, Jamf
//

import Cocoa
import Foundation

protocol SendingLoginInfoDelegate {
    func sendLoginInfo(loginInfo: (String,String,String,String,Int))
}

class LoginVC: NSViewController, URLSessionDelegate, NSTextFieldDelegate {

    var delegate: SendingLoginInfoDelegate? = nil

    @IBOutlet weak var displayName_Label: NSTextField!
    @IBOutlet weak var displayName_TextField: NSTextField!
    @IBOutlet weak var selectServer_Button: NSPopUpButton!
    @IBOutlet weak var selectedServer_ButtonCell: NSPopUpButtonCell!

    @IBOutlet weak var serverURL_Label: NSTextField!
    @IBOutlet weak var jamfProServer_textfield: NSTextField!
    @IBOutlet weak var jamfProUsername_textfield: NSTextField!
    @IBOutlet weak var jamfProPassword_textfield: NSSecureTextField!

    @IBOutlet weak var username_label: NSTextField!
    @IBOutlet weak var password_label: NSTextField!

    @IBOutlet weak var authMode_SegmentedControl: NSSegmentedControl!
    @IBAction func authMode_action(_ sender: NSSegmentedControl) {
        useApiClient = segmentToApiClient[sender.selectedSegment]
        userDefaults.set(useApiClient, forKey: "useApiClient")
        setLabels()
        if useApiClient == 0 {
            setSelectServerButton(listOfNames: sortedIntegrationNames)
            if lastTenantId != "" {
                jamfProServer_textfield.stringValue   = lastTenantId
                jamfProUsername_textfield.stringValue = lastClientId
                credentialsCheck()
            } else if !availableIntegrationsDict.isEmpty {
                if sortedIntegrationNames.count > 0 {
                    selectServer_Button.selectItem(at: 0)
                    selectServer_Action(selectServer_Button)
                }
            }
        } else {
            setSelectServerButton(listOfNames: sortedDisplayNames)
            if lastServer != "" {
                for (dn, info) in availableServersDict where (info["server"] as? String) == lastServer {
                    selectServer_Button.selectItem(withTitle: dn)
                    jamfProServer_textfield.stringValue = lastServer
                    credentialsCheck()
                    break
                }
            }
        }
        setWindowSize(setting: 1)
    }

    @IBOutlet weak var mode_Button: NSPopUpButton!
    
    @IBAction func mode_Action(_ sender: Any) {
        let selectedTitle = mode_Button.titleOfSelectedItem ?? "Jamf Pro"
        userDefaults.set(selectedTitle, forKey: "appMode")
        applyAppMode()
        if useApiClient == 0 {
            setSelectServerButton(listOfNames: sortedIntegrationNames)
            if lastTenantId != "" {
                jamfProServer_textfield.stringValue   = lastTenantId
                jamfProUsername_textfield.stringValue = lastClientId
                credentialsCheck()
            } else if !sortedIntegrationNames.isEmpty {
                selectServer_Button.selectItem(at: 0)
                selectServer_Action(selectServer_Button)
            }
        } else {
            setSelectServerButton(listOfNames: sortedDisplayNames)
            if lastServer != "" {
                for (dn, info) in availableServersDict where (info["server"] as? String) == lastServer {
                    selectServer_Button.selectItem(withTitle: dn)
                    jamfProServer_textfield.stringValue = lastServer
                    credentialsCheck()
                    break
                }
            }
        }
        setWindowSize(setting: 1)
    }
    
    @IBOutlet weak var login_Button: NSButton!
    @IBOutlet weak var quit_Button: NSButton!

    @IBOutlet weak var hideCreds_button: NSButton!
    @IBAction func hideCreds_action(_ sender: NSButton) {
        // kept for storyboard compatibility — hideCreds is always hidden in new design
    }

    @IBOutlet weak var saveCreds_button: NSButton!
    @IBAction func saveCredentials_Action(_ sender: Any) {
        userDefaults.set(saveCreds_button.state.rawValue == 1 ? 1 : 0, forKey: "saveCreds")
    }

    @IBOutlet weak var selectServer_Menu: NSMenu!

    // MARK: - Instance variables

    var availableServersDict      = [String:[String:AnyObject]]()
    var availableIntegrationsDict = [String:[String:AnyObject]]()
    var sortedDisplayNames        = [String]()
    var sortedIntegrationNames    = [String]()

    var currentServer     = ""
    var categoryName      = ""
    var uploadCount       = 0
    var totalObjects      = 0
    var uploadsComplete   = false
    var lastServer        = ""
    var lastUser          = ""
    var lastServerDN      = ""
    var lastIntegrationDN = ""
    var lastTenantId      = ""
    var lastClientId      = ""

    var region_Label                  = NSTextField(labelWithString: "Region:")
    var region_PopUp                  = NSPopUpButton()
    var tenantTopConstraint:          NSLayoutConstraint?
    var regionTopConstraint:          NSLayoutConstraint?
    var tenantBelowRegionConstraint:  NSLayoutConstraint?

    private var addItemTitle: String { useApiClient == 0 ? "Add Integration..." : "Add Server..." }
    private var segmentToApiClient: [Int] = [0, 1, 2, 3]

    // MARK: - IBActions

    @IBAction func selectServer_Action(_ sender: Any) {
        let selectedTitle = selectedServer_ButtonCell.titleOfSelectedItem ?? ""

        if selectedTitle == addItemTitle {
            displayName_TextField.becomeFirstResponder()
            displayName_Label.stringValue = "Display Name:"
//            displayName_Label.stringValue = useApiClient == 0 ? "Integration:" : "Display Name:"
            displayName_TextField.stringValue = ""
            selectServer_Button.isHidden = true
            displayName_TextField.isHidden = false
            serverURL_Label.isHidden = false
            jamfProServer_textfield.isHidden = false
            jamfProServer_textfield.stringValue = ""
            jamfProUsername_textfield.stringValue = ""
            jamfProPassword_textfield.stringValue = ""
            saveCreds_button.state = NSControl.StateValue(rawValue: 0)
            userDefaults.set(0, forKey: "saveCreds")
            hideCreds_button.isHidden = true
            quit_Button.title  = "Cancel"
            login_Button.title = "Add"
            setWindowSize(setting: 2)

        } else {
            setLabels()
            selectServer_Button.isHidden = false
            displayName_TextField.isHidden = true
            serverURL_Label.isHidden = false
            jamfProServer_textfield.isHidden = false
            hideCreds_button.isHidden = true
            displayName_TextField.stringValue = selectedTitle

            if NSEvent.modifierFlags.contains(.option) {
                let response = Alert.shared.display(header: "", message: "Are you sure you want to remove \(selectedTitle) from the list?", secondButton: "Cancel")
                if response != "Cancel" {
                    if useApiClient == 0 {
                        availableIntegrationsDict[selectedTitle] = nil
                        sortedIntegrationNames.removeAll { $0 == selectedTitle }
                        sharedDefaults!.set(availableIntegrationsDict, forKey: "integrationsDict")
                    } else {
                        availableServersDict[selectedTitle] = nil
                        sortedDisplayNames.removeAll { $0 == selectedTitle }
                        if saveServers { sharedDefaults!.set(availableServersDict, forKey: "serversDict") }
                    }
                    selectServer_Button.removeItem(withTitle: selectedTitle)
                    selectServer_Button.selectItem(withTitle: "")
                    jamfProServer_textfield.stringValue   = ""
                    jamfProUsername_textfield.stringValue = ""
                    jamfProPassword_textfield.stringValue = ""
                }
                return
            }

            if useApiClient == 0 {
                if let info = availableIntegrationsDict[selectedTitle] {
                    jamfProServer_textfield.stringValue   = info["tenantId"] as? String ?? ""
                    jamfProUsername_textfield.stringValue = info["clientId"] as? String ?? ""
                    let savedRegion = info["region"] as? String ?? "US"
                    if let idx = ["US", "EU", "APAC"].firstIndex(of: savedRegion) {
                        region_PopUp.selectItem(at: idx)
                    }
                    applyRegionSelection()
                }
            } else {
                jamfProServer_textfield.stringValue = (availableServersDict[selectedTitle]?["server"] as? String) ?? ""
            }

            credentialsCheck()
            quit_Button.title  = "Quit"
            login_Button.title = "Login"
        }
    }

    @IBAction func login_action(_ sender: Any) {
        JamfProServer.url         = (jamfProServer_textfield.stringValue.last == "/") ? String(jamfProServer_textfield.stringValue.dropLast()) : jamfProServer_textfield.stringValue
        JamfProServer.destination = jamfProServer_textfield.stringValue
        JamfProServer.username    = jamfProUsername_textfield.stringValue
        JamfProServer.password    = jamfProPassword_textfield.stringValue

        if useApiClient == 0 {
            JamfProServer.tenantId = JamfProServer.url
            applyRegionSelection()
        }

        var theSender = ""
        if (sender as? NSButton) != nil {
            theSender = (sender as? NSButton)!.title
        } else {
            theSender = sender as! String
        }

        if jamfProServer_textfield.stringValue == "" {
            let nameToRemove = (theSender == "Login") ? "\(selectServer_Button.titleOfSelectedItem ?? "")" : displayName_TextField.stringValue
            let deleteReply = Alert.shared.display(header: "Attention:", message: "Do you wish to remove \(nameToRemove) from the list?", secondButton: "Cancel")
            if deleteReply != "Cancel" && nameToRemove != addItemTitle {
                if useApiClient == 0 {
                    if availableIntegrationsDict[nameToRemove] != nil {
                        let idx = selectServer_Menu.indexOfItem(withTitle: nameToRemove)
                        if idx >= 0 { selectServer_Menu.removeItem(at: idx) }
                        availableIntegrationsDict[nameToRemove] = nil
                        sortedIntegrationNames.removeAll { $0 == nameToRemove }
                        lastTenantId = ""; lastClientId = ""; lastIntegrationDN = ""
                        jamfProServer_textfield.stringValue   = ""
                        jamfProUsername_textfield.stringValue = ""
                        jamfProPassword_textfield.stringValue = ""
                        sharedDefaults!.set(availableIntegrationsDict, forKey: "integrationsDict")
                        selectServer_Button.selectItem(withTitle: "")
                    }
                } else {
                    if availableServersDict[nameToRemove] != nil {
                        let serverIndex = selectServer_Menu.indexOfItem(withTitle: nameToRemove)
                        if serverIndex >= 0 { selectServer_Menu.removeItem(at: serverIndex) }
                        if userDefaults.string(forKey: "currentServer") == availableServersDict[nameToRemove]!["server"] as? String {
                            userDefaults.set("", forKey: "currentServer")
                        }
                        availableServersDict[nameToRemove] = nil
                        lastServer = ""
                        jamfProServer_textfield.stringValue   = ""
                        jamfProUsername_textfield.stringValue = ""
                        jamfProPassword_textfield.stringValue = ""
                        if saveServers { sharedDefaults!.set(availableServersDict, forKey: "serversDict") }
                        selectServer_Button.selectItem(withTitle: "")
                    }
                }
            }
            return
        } else if useApiClient != 0 {
            // For Pro modes: check if server URL changed for existing entry
            if jamfProServer_textfield.stringValue != availableServersDict[selectServer_Button.titleOfSelectedItem ?? ""]?["server"] as? String
                && selectServer_Button.titleOfSelectedItem ?? "" != addItemTitle {
                let serverToUpdate = (theSender == "Login") ? "\(selectServer_Button.titleOfSelectedItem ?? "")" : displayName_TextField.stringValue.fqdnFromUrl
                let updateReply = Alert.shared.display(header: "Attention:", message: "Do you wish to update the URL for \(serverToUpdate) to: \(jamfProServer_textfield.stringValue)", secondButton: "Cancel")
                if updateReply != "Cancel" && serverToUpdate != addItemTitle {
                    availableServersDict[serverToUpdate]?["server"] = jamfProServer_textfield.stringValue as AnyObject
                    if saveServers { sharedDefaults!.set(availableServersDict, forKey: "serversDict") }
                } else {
                    jamfProServer_textfield.stringValue = availableServersDict[selectServer_Button.titleOfSelectedItem ?? ""]?["server"] as? String ?? ""
                }
            }
        }

        if theSender == "Login" {
            JamfProServer.validToken = false
            JamfProServer.version    = ""
            let dataToBeSent = (displayName_TextField.stringValue, JamfProServer.url, JamfProServer.username, JamfProServer.password, saveCreds_button.state.rawValue)
            delegate?.sendLoginInfo(loginInfo: dataToBeSent)
            dismiss(self)

        } else {
            // "Add" — validate then save
            if displayName_TextField.stringValue == "" {
                let nameDefault = useApiClient == 0 ? JamfProServer.url : jamfProServer_textfield.stringValue.fqdnFromUrl
                let nameReply = Alert.shared.display(header: "Attention:", message: "Display name cannot be blank.\nUse \(nameDefault)?", secondButton: "Cancel")
                if nameReply == "Cancel" {
                    return
                } else {
                    displayName_TextField.stringValue = nameDefault
                }
            }

            login_Button.isEnabled = false

            let serverUrlForToken = useApiClient == 0 ? JamfProServer.tenantId : JamfProServer.destination
            let jamfUtf8Creds = "\(JamfProServer.username):\(JamfProServer.password)".data(using: .utf8)
            JamfProServer.base64Creds = (jamfUtf8Creds?.base64EncodedString()) ?? ""

            TokenDelegate.shared.getToken(serverUrl: serverUrlForToken, base64creds: JamfProServer.base64Creds) { [self]
                authResult in
                login_Button.isEnabled = true
                let (statusCode, theResult) = authResult

                if theResult == "success" {
                    let displayName = displayName_TextField.stringValue

                    if useApiClient == 0 {
                        // Platform: enforce list size
                        while availableIntegrationsDict.count >= maxServerList {
                            var oldest: Date? = nil
                            var oldestName = ""
                            for (dn, info) in availableIntegrationsDict {
                                let d = info["date"] as? Date ?? Date.distantFuture
                                if oldest == nil || d < oldest! { oldest = d; oldestName = dn }
                            }
                            if !oldestName.isEmpty { availableIntegrationsDict[oldestName] = nil }
                        }
                        availableIntegrationsDict[displayName] = [
                            "tenantId": JamfProServer.destination as AnyObject,
                            "clientId": JamfProServer.username    as AnyObject,
                            "region":   (region_PopUp.titleOfSelectedItem ?? "US") as AnyObject,
                            "date":     Date() as AnyObject
                        ]
                        sharedDefaults!.set(availableIntegrationsDict, forKey: "integrationsDict")

                        userDefaults.set(JamfProServer.tenantId, forKey: "lastTenantId")
                        userDefaults.set(JamfProServer.username,  forKey: "lastClientId")
                        userDefaults.set(displayName,             forKey: "lastIntegrationDN")
                        lastTenantId      = JamfProServer.tenantId
                        lastClientId      = JamfProServer.username
                        lastIntegrationDN = displayName

                        if saveCreds_button.state.rawValue == 1 {
                            Credentials.shared.save(service: JamfProServer.tenantId, account: JamfProServer.username, credential: JamfProServer.password)
                        }

                        if sortedIntegrationNames.firstIndex(of: displayName) == nil {
                            sortedIntegrationNames.append(displayName)
                        }
                        setSelectServerButton(listOfNames: sortedIntegrationNames)
                        selectServer_Button.selectItem(withTitle: displayName)

                    } else {
                        // Pro modes: enforce list size
                        while availableServersDict.count >= maxServerList {
                            var lastUsedDate = Date()
                            var serverName   = ""
                            for (dn, serverInfo) in availableServersDict {
                                if let _ = serverInfo["date"] {
                                    if (serverInfo["date"] as! Date) < lastUsedDate {
                                        lastUsedDate = serverInfo["date"] as! Date
                                        serverName = dn
                                    }
                                } else {
                                    serverName = dn
                                    break
                                }
                            }
                            availableServersDict[serverName] = nil
                        }
                        availableServersDict[displayName] = ["server": JamfProServer.destination as AnyObject, "date": Date() as AnyObject]
                        if saveServers { sharedDefaults!.set(availableServersDict, forKey: "serversDict") }

                        userDefaults.set(JamfProServer.destination, forKey: "currentServer")
                        userDefaults.set(JamfProServer.username,    forKey: "username")

                        if saveCreds_button.state.rawValue == 1 {
                            Credentials.shared.save(service: JamfProServer.destination.fqdnFromUrl, account: JamfProServer.username, credential: JamfProServer.password)
                        }

                        if sortedDisplayNames.firstIndex(of: displayName) == nil {
                            sortedDisplayNames.append(displayName)
                        }
                        setSelectServerButton(listOfNames: sortedDisplayNames)
                        selectServer_Button.selectItem(withTitle: displayName)
                    }

                    displayName_Label.stringValue = useApiClient == 0 ? "Integration:" : "Server:"
                    selectServer_Button.isHidden = false
                    displayName_TextField.isHidden = true
                    quit_Button.title  = "Quit"
                    login_Button.title = "Login"

                    login_action("Login")

                } else {
                    _ = Alert.shared.display(header: "Attention:", message: "Failed to generate token. HTTP status code: \(statusCode)", secondButton: "")
                }
            }
        }
    }

    @IBAction func quit_Action(_ sender: NSButton) {
        if sender.title == "Quit" {
            dismiss(self)
            NSApplication.shared.terminate(self)
        } else if login_Button.title == "Add" {
            setLabels()
            selectServer_Button.isHidden = false
            displayName_TextField.isHidden = true
            serverURL_Label.isHidden = false
            jamfProServer_textfield.isHidden = false
            hideCreds_button.isHidden = true

            if useApiClient == 0 {
                if lastTenantId != "" {
                    displayName_TextField.stringValue = lastIntegrationDN
                    jamfProServer_textfield.stringValue   = lastTenantId
                    jamfProUsername_textfield.stringValue = lastClientId
                    if sortedIntegrationNames.firstIndex(of: lastIntegrationDN) != nil {
                        selectServer_Button.selectItem(withTitle: lastIntegrationDN)
                    }
                    credentialsCheck()
                } else {
                    login_Button.isEnabled              = false
                    jamfProServer_textfield.isEnabled   = false
                    jamfProUsername_textfield.isEnabled = false
                    jamfProPassword_textfield.isEnabled = false
                }
            } else {
                if lastServer != "" {
                    var tmpName = ""
                    for (dn, serverInfo) in availableServersDict {
                        tmpName = dn
                        if (serverInfo["server"] as? String) == lastServer { break }
                    }
                    selectServer_Button.selectItem(withTitle: tmpName)
                    displayName_TextField.stringValue   = tmpName
                    jamfProServer_textfield.stringValue = (availableServersDict[tmpName]?["server"] as? String) ?? ""
                    credentialsCheck()
                } else {
                    login_Button.isEnabled              = false
                    jamfProServer_textfield.isEnabled   = false
                    jamfProUsername_textfield.isEnabled = false
                    jamfProPassword_textfield.isEnabled = false
                }
            }
            quit_Button.title  = "Quit"
            login_Button.title = "Login"
        } else {
            dismiss(self)
        }
    }

    // MARK: - Text field delegates

    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            switch textField.identifier!.rawValue {
            case "server":
                let accountDict = Credentials.shared.retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
                if accountDict.count == 1 {
                    for (username, password) in accountDict {
                        jamfProUsername_textfield.stringValue = username
                        jamfProPassword_textfield.stringValue = password
                    }
                } else {
                    jamfProPassword_textfield.stringValue = ""
                }
            case "username":
                let accountDict = Credentials.shared.retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
                jamfProPassword_textfield.stringValue = ""
                for (username, password) in accountDict {
                    if username == jamfProUsername_textfield.stringValue {
                        jamfProUsername_textfield.stringValue = username
                        jamfProPassword_textfield.stringValue = password
                        break
                    }
                }
            default:
                break
            }
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            switch textField.identifier!.rawValue {
            case "server":
                if jamfProUsername_textfield.stringValue != "" || jamfProPassword_textfield.stringValue != "" {
                    let accountDict = Credentials.shared.retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
                    if accountDict.count == 1 {
                        for (username, password) in accountDict {
                            jamfProUsername_textfield.stringValue = username
                            jamfProPassword_textfield.stringValue = password
                        }
                    } else {
                        jamfProUsername_textfield.stringValue = ""
                        jamfProPassword_textfield.stringValue = ""
                        setWindowSize(setting: 1)
                    }
                }
            default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func applyAppMode() {
        let mode = mode_Button.titleOfSelectedItem ?? "Jamf Pro"
        switch mode {
        case "Jamf School":
            segmentToApiClient = [3]
            authMode_SegmentedControl.segmentCount = 1
            authMode_SegmentedControl.setLabel("School", forSegment: 0)
            useApiClient = 3
            userDefaults.set(useApiClient, forKey: "useApiClient")
            authMode_SegmentedControl.selectedSegment = 0
        case "Both":
            segmentToApiClient = [0, 1, 2, 3]
            authMode_SegmentedControl.segmentCount = 4
            authMode_SegmentedControl.setLabel("Platform",       forSegment: 0)
            authMode_SegmentedControl.setLabel("Pro - API Client", forSegment: 1)
            authMode_SegmentedControl.setLabel("Pro - Username", forSegment: 2)
            authMode_SegmentedControl.setLabel("School",         forSegment: 3)
            authMode_SegmentedControl.selectedSegment = segmentToApiClient.firstIndex(of: useApiClient) ?? 2
        default: // "Jamf Pro"
            segmentToApiClient = [0, 1, 2]
            authMode_SegmentedControl.segmentCount = 3
            authMode_SegmentedControl.setLabel("Platform",       forSegment: 0)
            authMode_SegmentedControl.setLabel("Pro - API Client", forSegment: 1)
            authMode_SegmentedControl.setLabel("Pro - Username", forSegment: 2)
            if useApiClient == 3 {
                useApiClient = 2
                userDefaults.set(useApiClient, forKey: "useApiClient")
            }
            authMode_SegmentedControl.selectedSegment = segmentToApiClient.firstIndex(of: useApiClient) ?? 2
        }
        setLabels()
    }

    func credentialsCheck() {
        let service = jamfProServer_textfield.stringValue.fqdnFromUrl
        let filterAccount = (useApiClient == 0 && !lastClientId.isEmpty) ? lastClientId : jamfProUsername_textfield.stringValue
        let accountDict = Credentials.shared.retrieve(service: service, account: filterAccount)
        if accountDict.count == 1 {
            for (username, password) in accountDict {
                jamfProUsername_textfield.stringValue = username
                jamfProPassword_textfield.stringValue = password
                hideCreds_button.isHidden = true
                saveCreds_button.state = NSControl.StateValue(rawValue: 1)
                userDefaults.set(1, forKey: "saveCreds")
                setWindowSize(setting: 1)
            }
        } else {
            if useApiClient != 0 {
                jamfProUsername_textfield.stringValue = userDefaults.string(forKey: "username") ?? ""
            }
            jamfProPassword_textfield.stringValue = ""
            setWindowSize(setting: 1)
        }
    }

    func fetchPassword() {
        let service = jamfProServer_textfield.stringValue.fqdnFromUrl
        let account = (useApiClient == 0 && !lastClientId.isEmpty) ? lastClientId : jamfProUsername_textfield.stringValue
        let accountDict = Credentials.shared.retrieve(service: service, account: account)
        if accountDict.count == 1 {
            for (username, password) in accountDict {
                jamfProUsername_textfield.stringValue = username
                jamfProPassword_textfield.stringValue = password
            }
        } else {
            jamfProPassword_textfield.stringValue = ""
        }
    }

    func setLabels() {
        switch useApiClient {
        case 0:
            displayName_Label.stringValue             = "Integration:"
            serverURL_Label.stringValue               = "Tenant ID:"
            username_label.stringValue                = "Client ID:"
            password_label.stringValue                = "Client Secret:"
            jamfProServer_textfield.placeholderString = "copied from accounts.jamf.com"
        case 1:
            displayName_Label.stringValue             = "Server:"
            serverURL_Label.stringValue               = "Server URL:"
            username_label.stringValue                = "Client ID:"
            password_label.stringValue                = "Client Secret:"
            jamfProServer_textfield.placeholderString = "https://your.jamf.server"
        case 3:
            displayName_Label.stringValue             = "Server:"
            serverURL_Label.stringValue               = "Server URL:"
            username_label.stringValue                = "Network ID:"
            password_label.stringValue                = "API Key:"
            jamfProServer_textfield.placeholderString = "https://your.jamfschool.server"
        default:
            displayName_Label.stringValue             = "Server:"
            serverURL_Label.stringValue               = "Server URL:"
            username_label.stringValue                = "Username:"
            password_label.stringValue                = "Password:"
            jamfProServer_textfield.placeholderString = "https://your.jamf.server"
        }
        updateRegionRowVisibility()
    }

    func setSelectServerButton(listOfNames: [String]) {
        let sorted = listOfNames.sorted { $0.localizedCompare($1) == .orderedAscending }
        if useApiClient == 0 { sortedIntegrationNames = sorted } else { sortedDisplayNames = sorted }
        selectServer_Button.removeAllItems()
        selectServer_Button.addItems(withTitles: sorted)
        let count = selectServer_Menu.numberOfItems
        selectServer_Menu.insertItem(NSMenuItem.separator(), at: count)
        selectServer_Button.addItem(withTitle: addItemTitle)
    }

    func setWindowSize(setting: Int) {
        let extraHeight = (useApiClient == 0) ? 42 : 0
        hideCreds_button.isHidden = true

        switch setting {
        case 0, 1:
            preferredContentSize = CGSize(width: 518, height: 252 + extraHeight)
        default:
            preferredContentSize = CGSize(width: 518, height: 252 + extraHeight)
        }

        jamfProServer_textfield.isHidden   = false
        jamfProUsername_textfield.isHidden = false
        jamfProPassword_textfield.isHidden = false
        serverURL_Label.isHidden           = false
        username_label.isHidden            = false
        password_label.isHidden            = false
        saveCreds_button.isHidden          = false

        hideCreds_button.state = NSControl.StateValue(rawValue: 1)
        hideCreds_button.image = NSImage(named: NSImage.touchBarGoDownTemplateName)
        updateRegionRowVisibility()
    }

    // MARK: - Region row

    private func setupRegionRow() {
        guard let container = jamfProServer_textfield.superview else { return }

        region_Label.translatesAutoresizingMaskIntoConstraints = false
        region_Label.isEditable      = false
        region_Label.isBezeled       = false
        region_Label.drawsBackground = false
        region_Label.alignment       = .right

        region_PopUp.translatesAutoresizingMaskIntoConstraints = false
        region_PopUp.addItems(withTitles: ["US", "EU", "APAC"])
        region_PopUp.target = self
        region_PopUp.action = #selector(regionChanged(_:))

        container.addSubview(region_Label)
        container.addSubview(region_PopUp)

        NSLayoutConstraint.activate([
            region_Label.leadingAnchor.constraint(equalTo: serverURL_Label.leadingAnchor),
            region_Label.trailingAnchor.constraint(equalTo: serverURL_Label.trailingAnchor),
            region_Label.centerYAnchor.constraint(equalTo: region_PopUp.centerYAnchor),
            region_PopUp.leadingAnchor.constraint(equalTo: jamfProServer_textfield.leadingAnchor),
            region_PopUp.widthAnchor.constraint(equalToConstant: 120),
        ])

        regionTopConstraint = region_PopUp.topAnchor.constraint(
            equalTo: selectServer_Button.bottomAnchor, constant: 10)
        tenantBelowRegionConstraint = jamfProServer_textfield.topAnchor.constraint(
            equalTo: region_PopUp.bottomAnchor, constant: 10)

        for c in container.constraints where
            c.firstItem === jamfProServer_textfield &&
            c.firstAttribute == .top &&
            c.secondItem === selectServer_Button &&
            c.secondAttribute == .bottom {
            tenantTopConstraint = c
            break
        }

        if lastIntegrationDN != "",
           let info = availableIntegrationsDict[lastIntegrationDN],
           let savedRegion = info["region"] as? String,
           let idx = ["US", "EU", "APAC"].firstIndex(of: savedRegion) {
            region_PopUp.selectItem(at: idx)
        }
        applyRegionSelection()
    }

    @objc private func regionChanged(_ sender: NSPopUpButton) {
        applyRegionSelection()
    }

    private func applyRegionSelection() {
        switch region_PopUp.titleOfSelectedItem ?? "US" {
        case "EU":   JamfProServer.region = "eu"
        case "APAC": JamfProServer.region = "apac"
        default:     JamfProServer.region = "us"
        }
    }

    private func updateRegionRowVisibility() {
        let show = (useApiClient == 0)
        region_Label.isHidden = !show
        region_PopUp.isHidden = !show
        if show {
            tenantTopConstraint?.isActive          = false
            regionTopConstraint?.isActive          = true
            tenantBelowRegionConstraint?.isActive  = true
        } else {
            tenantBelowRegionConstraint?.isActive  = false
            regionTopConstraint?.isActive          = false
            tenantTopConstraint?.isActive          = true
        }
    }

    // MARK: - viewDidLoad

    override func viewDidLoad() {
        super.viewDidLoad()

        migrateAppGroupSettings()

        hideCreds_button.isHidden = true

        jamfProServer_textfield.delegate   = self
        jamfProUsername_textfield.delegate = self

        // Restore auth mode
        useApiClient = userDefaults.integer(forKey: "useApiClient")
        authMode_SegmentedControl.selectedSegment = useApiClient

        // Ensure sharedDefaults keys exist
        if !FileManager.default.fileExists(atPath: sharedSettingsPlistUrl.path) {
            sharedDefaults!.set(Date(), forKey: "created")
            sharedDefaults!.set([String:AnyObject](), forKey: "serversDict")
        }
        if sharedDefaults!.object(forKey: "integrationsDict") == nil {
            sharedDefaults!.set([String:AnyObject](), forKey: "integrationsDict")
        }
        if (sharedDefaults!.object(forKey: "serversDict") as? [String:AnyObject] ?? [:]).count == 0 {
            sharedDefaults!.set(availableServersDict, forKey: "serversDict")
        }

        // Load integrations
        availableIntegrationsDict = sharedDefaults!.object(forKey: "integrationsDict") as? [String:[String:AnyObject]] ?? [:]
        lastTenantId      = userDefaults.string(forKey: "lastTenantId")      ?? ""
        lastClientId      = userDefaults.string(forKey: "lastClientId")      ?? ""
        lastIntegrationDN = userDefaults.string(forKey: "lastIntegrationDN") ?? ""

        // Load servers
        availableServersDict = sharedDefaults!.object(forKey: "serversDict") as? [String:[String:AnyObject]] ?? [:]
        lastServer = userDefaults.string(forKey: "currentServer") ?? ""
        lastUser   = userDefaults.string(forKey: "username")      ?? ""

        // Trim server list to max
        while availableServersDict.count >= maxServerList {
            var lastUsedDate = Date()
            var serverName   = ""
            for (displayName, serverInfo) in availableServersDict {
                if let _ = serverInfo["date"] {
                    if (serverInfo["date"] as! Date) < lastUsedDate && (serverInfo["server"] as! String).prefix(1) != "/" {
                        lastUsedDate = serverInfo["date"] as! Date
                        serverName = displayName
                    }
                } else {
                    serverName = displayName
                    break
                }
            }
            availableServersDict[serverName] = nil
        }

        // Build sorted server names
        var foundServer = false
        for (displayName, serverInfo) in availableServersDict {
            if displayName != "", let serverStr = serverInfo["server"] as? String, serverStr.prefix(1) != "/" {
                sortedDisplayNames.append(displayName)
                if serverStr == lastServer && lastServer != "" {
                    foundServer = true
                    lastServerDN = displayName
                }
            } else {
                availableServersDict[displayName] = nil
            }
        }
        if !foundServer && lastServer != "" && availableServersDict.isEmpty {
            availableServersDict[lastServer.fqdnFromUrl] = ["server": lastServer as AnyObject, "date": Date() as AnyObject]
            lastServerDN = lastServer.fqdnFromUrl
            sortedDisplayNames.append(lastServerDN)
        }

        // Build sorted integration names
        for (dn, _) in availableIntegrationsDict where dn != "" {
            if sortedIntegrationNames.firstIndex(of: dn) == nil {
                sortedIntegrationNames.append(dn)
            }
        }

        saveCreds_button.state = NSControl.StateValue(userDefaults.integer(forKey: "saveCreds"))
        jamfProUsername_textfield.stringValue = lastUser

        setLabels()

        if useApiClient == 0 {
            // Platform mode startup
            setSelectServerButton(listOfNames: sortedIntegrationNames)
            if !sortedIntegrationNames.isEmpty {
                if sortedIntegrationNames.firstIndex(of: lastIntegrationDN) != nil {
                    selectServer_Button.selectItem(withTitle: lastIntegrationDN)
                } else {
                    selectServer_Button.selectItem(at: 0)
                }
                if lastTenantId != "" {
                    jamfProServer_textfield.stringValue   = lastTenantId
                    jamfProUsername_textfield.stringValue = lastClientId
                    credentialsCheck()
                }
            } else {
                setSelectServerButton(listOfNames: [])
                selectServer_Button.selectItem(withTitle: addItemTitle)
                login_Button.title = "Add"
                selectServer_Action(self)
                setWindowSize(setting: 2)
            }
        } else {
            // Pro modes startup
            setSelectServerButton(listOfNames: sortedDisplayNames)
            if sortedDisplayNames.firstIndex(of: lastServerDN) != nil {
                selectServer_Button.selectItem(withTitle: lastServerDN)
            } else {
                selectServer_Button.selectItem(withTitle: "")
            }
            jamfProServer_textfield.stringValue = lastServer

            if availableServersDict.count != 0 {
                if jamfProServer_textfield.stringValue != "" {
                    credentialsCheck()
                }
            } else {
                jamfProServer_textfield.stringValue = ""
                setSelectServerButton(listOfNames: [])
                selectServer_Button.selectItem(withTitle: addItemTitle)
                login_Button.title = "Add"
                selectServer_Action(self)
                setWindowSize(setting: 2)
            }
        }

        if loginAction == "changeServer" {
            quit_Button.title = "Cancel"
        }

        setupRegionRow()
        updateRegionRowVisibility()

        let savedAppMode = userDefaults.string(forKey: "appMode") ?? "Both"
        mode_Button.selectItem(withTitle: savedAppMode)
        applyAppMode()

        setWindowSize(setting: 1)

        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
    }

    // MARK: - Migration

    private func migrateAppGroupSettings() {
        let _sharedContainerUrl     = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.PS2F6S478M.jamfie.SharedJPMA") ?? URL(fileURLWithPath: "/private/tmp")
        let _sharedSettingsPlistUrl = _sharedContainerUrl.appendingPathComponent("Library/Preferences/group.PS2F6S478M.jamfie.SharedJPMA.plist")

        if !FileManager.default.fileExists(atPath: sharedSettingsPlistUrl.path(percentEncoded: false)) {
            sharedDefaults!.set(Date(), forKey: "created")
            sharedDefaults!.set([String:AnyObject](), forKey: "serversDict")
        }
        let settingsMigrated = sharedDefaults!.object(forKey: "migrated") as? String ?? "false"
        if settingsMigrated != "true" {
            if FileManager.default.fileExists(atPath: _sharedSettingsPlistUrl.path(percentEncoded: false)) {
                WriteToLog.shared.message("[migrateAppGroupSettings] legacy settings file exists")
                if FileManager.default.isReadableFile(atPath: _sharedSettingsPlistUrl.path(percentEncoded: false)) {
                    WriteToLog.shared.message("[migrateAppGroupSettings] file is readable")
                    do {
                        let data = try Data(contentsOf: _sharedSettingsPlistUrl)
                        WriteToLog.shared.message("[migrateAppGroupSettings] file settings to data")
                        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
                        WriteToLog.shared.message("[migrateAppGroupSettings] converted to dictionary")
                        for (key, value) in plist ?? [:] {
                            sharedDefaults!.set(value, forKey: key)
                        }
                        sharedDefaults!.set("true" as AnyObject, forKey: "migrated")
                        WriteToLog.shared.message("[migrateAppGroupSettings] migrated settings")
                    } catch {
                        WriteToLog.shared.message("[migrateAppGroupSettings] failed to migrate settings: \(error.localizedDescription)")
                    }
                } else {
                    WriteToLog.shared.message("[migrateAppGroupSettings] file is not readable")
                }
            } else {
                do {
                    sharedDefaults!.set("true" as AnyObject, forKey: "migrated")
                    try FileManager.default.copyItem(atPath: sharedSettingsPlistUrl.path(percentEncoded: false), toPath: _sharedSettingsPlistUrl.path(percentEncoded: false))
                } catch {
                    WriteToLog.shared.message("[migrateAppGroupSettings] failed to create group preference file")
                }
            }
        }
    }
}

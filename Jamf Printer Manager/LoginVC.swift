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
    
    @IBOutlet weak var header_TextField: NSTextField!
    @IBOutlet weak var displayName_Label: NSTextField!
    @IBOutlet weak var displayName_TextField: NSTextField!
    @IBOutlet weak var selectServer_Button: NSPopUpButton!
    
    @IBOutlet weak var selectedServer_ButtonCell: NSPopUpButtonCell!
    
    
    @IBAction func selectServer_Action(_ sender: Any) {
        if selectedServer_ButtonCell.titleOfSelectedItem == "Add Server..." {
            
            displayName_TextField.becomeFirstResponder()
        
            header_TextField.isHidden = false
            header_TextField.wantsLayer = true
            header_TextField.stringValue = "Enter the information for the Jamf Pro server you'd like to manage."
            header_TextField.frame.size.height = 41.0
            
            displayName_TextField.insertText("hello")
            displayName_Label.stringValue = "Display Name:"
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
            useApiClient_button.state = NSControl.StateValue(rawValue: 0)
            userDefaults.set(0, forKey: "useApiClient")
            useApiClient_button.isHidden = true
            quit_Button.title  = "Cancel"
            login_Button.title = "Add"
            
            setWindowSize(setting: 2)
        } else {
            header_TextField.isHidden = true
            header_TextField.wantsLayer = true
            header_TextField.stringValue = ""
            header_TextField.frame.size.height = 0.0
            displayName_Label.stringValue = "Server:"
            selectServer_Button.isHidden = false
            displayName_TextField.isHidden = true
            serverURL_Label.isHidden = false
            jamfProServer_textfield.isHidden = false
            hideCreds_button.isHidden = false
            displayName_TextField.stringValue = selectedServer_ButtonCell.title
            jamfProServer_textfield.stringValue = (availableServersDict[selectedServer_ButtonCell.title]?["server"])! as! String
            
            if NSEvent.modifierFlags.contains(.option) {
                let selectedServer =  selectServer_Button.titleOfSelectedItem!
                let response = Alert.shared.display(header: "", message: "Are you sure you want to remove \(selectedServer) from the list?", secondButton: "Cancel")
                    if response == "Cancel" {
                        return
                    } else {
                        for (displayName, _) in availableServersDict {
                            if displayName == selectedServer {
                                availableServersDict[displayName] = nil
                                selectServer_Button.removeItem(withTitle: selectedServer)
                                sortedDisplayNames.removeAll(where: {$0 == displayName})
                            }
                        }
                        if saveServers {
                            sharedDefaults!.set(availableServersDict, forKey: "serversDict")
                        }
                        selectServer_Button.selectItem(withTitle: "")
                        jamfProServer_textfield.stringValue   = ""
                        jamfProUsername_textfield.stringValue = ""
                        jamfProPassword_textfield.stringValue = ""
                        selectServer_Button.selectItem(withTitle: "")
                    }
                
                return
            }
            
            credentialsCheck()
            quit_Button.title  = "Quit"
            login_Button.title = "Login"
        }
    }
    @IBOutlet weak var selectServer_Menu: NSMenu!
    
    @IBOutlet weak var hideCreds_button: NSButton!
    
    @IBOutlet weak var serverURL_Label: NSTextField!
    
    @IBOutlet weak var jamfProServer_textfield: NSTextField!
    @IBOutlet weak var jamfProUsername_textfield: NSTextField!
    @IBOutlet weak var jamfProPassword_textfield: NSSecureTextField!
    
    @IBOutlet weak var username_label: NSTextField!
    @IBOutlet weak var password_label: NSTextField!
    
    @IBOutlet weak var useApiClient_button: NSButton!
    @IBAction func useApiClient_Action(_ sender: NSButton) {
        setLabels()
        userDefaults.set(useApiClient_button.state.rawValue, forKey: "useApiClient")
        fetchPassword()
    }
    
    @IBOutlet weak var login_Button: NSButton!
    @IBOutlet weak var quit_Button: NSButton!
    
    var availableServersDict   = [String:[String:AnyObject]]()
    
    var currentServer          = ""
    var categoryName           = ""
    var uploadCount            = 0
    var totalObjects           = 0
    var uploadsComplete        = false
    var sortedDisplayNames      = [String]()
    var lastServer             = ""
    var lastUser               = ""
    var lastServerDN           = ""

    @IBOutlet weak var saveCreds_button: NSButton!
    
    @IBAction func hideCreds_action(_ sender: NSButton) {
        hideCreds_button.image = (hideCreds_button.state.rawValue == 0) ? NSImage(named: NSImage.rightFacingTriangleTemplateName):NSImage(named: NSImage.touchBarGoDownTemplateName)
        userDefaults.set("\(hideCreds_button.state.rawValue)", forKey: "hideCreds")
        setWindowSize(setting: hideCreds_button.state.rawValue)
    }
    
    @IBAction func login_action(_ sender: Any) {
        JamfProServer.url         = (jamfProServer_textfield.stringValue.last == "/") ? String(jamfProServer_textfield.stringValue.dropLast()):jamfProServer_textfield.stringValue
        
        JamfProServer.destination = jamfProServer_textfield.stringValue
        JamfProServer.username    = jamfProUsername_textfield.stringValue
        JamfProServer.password    = jamfProPassword_textfield.stringValue
        
        var theSender = ""

        if (sender as? NSButton) != nil {
            theSender = (sender as? NSButton)!.title
        } else {
            theSender = sender as! String
        }
        
        if jamfProServer_textfield.stringValue == "" {
            let serverToRemove = (theSender == "Login") ? "\(selectServer_Button.titleOfSelectedItem ?? "")":displayName_TextField.stringValue
            let deleteReply = Alert.shared.display(header: "Attention:", message: "Do you wish to remove \(serverToRemove) from the list?", secondButton: "Cancel")
            if deleteReply != "Cancel" && serverToRemove != "Add Server..." {
                if availableServersDict[serverToRemove] != nil {
                    let serverIndex = selectServer_Menu.indexOfItem(withTitle: serverToRemove)
                    selectServer_Menu.removeItem(at: serverIndex)
                    if userDefaults.string(forKey: "currentServer") == availableServersDict[serverToRemove]!["server"] as? String {
                        userDefaults.set("", forKey: "currentServer")
                    }
                    availableServersDict[serverToRemove]  = nil
                    lastServer                            = ""
                    jamfProServer_textfield.stringValue   = ""
                    jamfProUsername_textfield.stringValue = ""
                    jamfProPassword_textfield.stringValue = ""
                    if saveServers {
                        sharedDefaults!.set(availableServersDict, forKey: "serversDict")
                    }
                    selectServer_Button.selectItem(withTitle: "")
                }
                return
            } else {
                return
            }
        } else if jamfProServer_textfield.stringValue != availableServersDict[selectServer_Button.titleOfSelectedItem!]?["server"] as? String && selectServer_Button.titleOfSelectedItem ?? "" != "Add Server..." {
            let serverToUpdate = (theSender == "Login") ? "\(selectServer_Button.titleOfSelectedItem ?? "")":displayName_TextField.stringValue.fqdnFromUrl
            let updateReply = Alert.shared.display(header: "Attention:", message: "Do you wish to update the URL for \(serverToUpdate) to: \(jamfProServer_textfield.stringValue)", secondButton: "Cancel")
            if updateReply != "Cancel" && serverToUpdate != "Add Server..." {
                availableServersDict[serverToUpdate]?["server"] = jamfProServer_textfield.stringValue as AnyObject
                if saveServers {
                    sharedDefaults!.set(availableServersDict, forKey: "serversDict")
                }
            } else {
                jamfProServer_textfield.stringValue = availableServersDict[selectServer_Button.titleOfSelectedItem!]?["server"] as! String
            }
        }
        
        if theSender == "Login" {
            JamfProServer.validToken = false
            JamfProServer.version    = ""
            let dataToBeSent = (displayName_TextField.stringValue, JamfProServer.url, JamfProServer.username, JamfProServer.password, saveCreds_button.state.rawValue)
            delegate?.sendLoginInfo(loginInfo: dataToBeSent)
            dismiss(self)
        } else {
            if displayName_TextField.stringValue == "" {
                let nameReply = Alert.shared.display(header: "Attention:", message: "Display name cannot be blank.\nUse \(jamfProServer_textfield.stringValue.fqdnFromUrl)?", secondButton: "Cancel")
                if nameReply == "Cancel" {
                    return
                } else {
                    displayName_TextField.stringValue = jamfProServer_textfield.stringValue.fqdnFromUrl
                }
            }
            
            login_Button.isEnabled = false
            
            let jamfUtf8Creds = "\(JamfProServer.username):\(JamfProServer.password)".data(using: String.Encoding.utf8)
            JamfProServer.base64Creds = (jamfUtf8Creds?.base64EncodedString())!
            TokenDelegate.shared.getToken(serverUrl: JamfProServer.destination, base64creds: JamfProServer.base64Creds) { [self]
                authResult in
                
                login_Button.isEnabled = true
                
                let (statusCode,theResult) = authResult
                if theResult == "success" {
                    
                    header_TextField.isHidden          = true
                    header_TextField.wantsLayer        = true
                    header_TextField.stringValue       = ""
                    header_TextField.frame.size.height = 0.0
                    
                    sortedDisplayNames.append(displayName_TextField.stringValue)
                    while availableServersDict.count >= maxServerList {
                        var lastUsedDate = Date()
                        var serverName   = ""
                        for (displayName, serverInfo) in availableServersDict {
                            if let _ = serverInfo["date"] {
                                if (serverInfo["date"] as! Date) < lastUsedDate {
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
                    
                    availableServersDict[displayName_TextField.stringValue] = ["server":JamfProServer.destination as AnyObject,"date":Date() as AnyObject]
                    if saveServers {
                        sharedDefaults!.set(availableServersDict, forKey: "serversDict")
                    }
                    print("[login_action] availableServers: \(availableServersDict)")
                    
                    userDefaults.set(JamfProServer.destination, forKey: "currentServer")
                    userDefaults.set(JamfProServer.username, forKey: "username")
                    
                    setSelectServerButton(listOfServers: sortedDisplayNames)
                    selectServer_Button.selectItem(withTitle: displayName_TextField.stringValue)
                    displayName_Label.stringValue = "Server:"
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
            header_TextField.isHidden = true
            header_TextField.wantsLayer = true
            header_TextField.stringValue = ""
            header_TextField.frame.size.height = 0.0
            displayName_Label.stringValue = "Server:"
            selectServer_Button.isHidden = false
            displayName_TextField.isHidden = true
            serverURL_Label.isHidden = false
            jamfProServer_textfield.isHidden = false
            hideCreds_button.isHidden = false
            if lastServer != "" {
                var tmpName = ""
                for (dName, serverInfo) in availableServersDict {
                    tmpName = dName
                    if (serverInfo["server"] as! String) == lastServer { break }
                }
                selectServer_Button.selectItem(withTitle: tmpName)
                displayName_TextField.stringValue = tmpName
                jamfProServer_textfield.stringValue = (availableServersDict[tmpName]?["server"])! as! String
                credentialsCheck()
            } else {
                login_Button.isEnabled              = false
                jamfProServer_textfield.isEnabled   = false
                jamfProUsername_textfield.isEnabled = false
                jamfProPassword_textfield.isEnabled = false
            }
            quit_Button.title  = "Quit"
            login_Button.title = "Login"
        } else {
            dismiss(self)
        }
    }
    
    @IBAction func saveCredentials_Action(_ sender: Any) {
        if saveCreds_button.state.rawValue == 1 {
            userDefaults.set(1, forKey: "saveCreds")
        } else {
            userDefaults.set(0, forKey: "saveCreds")
        }
    }
    
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
    
    func credentialsCheck() {
        print("server: \(jamfProServer_textfield.stringValue.fqdnFromUrl)")
        print("  user: \(jamfProUsername_textfield.stringValue.fqdnFromUrl)")
        let accountDict = Credentials.shared.retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
        if accountDict.count == 1 {
            for (username, password) in accountDict {
                jamfProUsername_textfield.stringValue = username
                jamfProPassword_textfield.stringValue = password
                let windowState = (userDefaults.integer(forKey: "hideCreds") == 1) ? 1:0
                hideCreds_button.isHidden = false
                saveCreds_button.state = NSControl.StateValue(rawValue: 1)
                userDefaults.set(1, forKey: "saveCreds")
                setWindowSize(setting: windowState)
            }
        } else {
            jamfProUsername_textfield.stringValue = userDefaults.string(forKey: "username") ?? ""
            jamfProPassword_textfield.stringValue = ""
            setWindowSize(setting: 1)
        }
    }
    
    func fetchPassword() {
        let accountDict = Credentials.shared.retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
        
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
        useApiClient = useApiClient_button.state.rawValue
        if useApiClient == 0 {
            username_label.stringValue = "Username:"
            password_label.stringValue = "Password:"
        } else {
            username_label.stringValue = "Client ID:"
            password_label.stringValue = "Client Secret:"
        }
    }
    
    func setSelectServerButton(listOfServers: [String]) {
        sortedDisplayNames = listOfServers.sorted{ $0.localizedCompare($1) == .orderedAscending }
        selectServer_Button.removeAllItems()
        selectServer_Button.addItems(withTitles: sortedDisplayNames)
        let serverCount = selectServer_Menu.numberOfItems
        selectServer_Menu.insertItem(NSMenuItem.separator(), at: serverCount)
        selectServer_Button.addItem(withTitle: "Add Server...")
    }
    
    func setWindowSize(setting: Int) {
        if setting == 0 {
            preferredContentSize = CGSize(width: 450, height: 115)
            hideCreds_button.toolTip = "show username/password fields"
            jamfProServer_textfield.isHidden   = true
            jamfProUsername_textfield.isHidden = true
            jamfProPassword_textfield.isHidden = true
            serverURL_Label.isHidden           = true
            username_label.isHidden            = true
            password_label.isHidden            = true
            saveCreds_button.isHidden          = true
            useApiClient_button.isHidden       = true
        } else if setting == 1 {
            preferredContentSize = CGSize(width: 450, height: 220)
            hideCreds_button.toolTip = "hide username/password fields"
            jamfProServer_textfield.isHidden   = false
            jamfProUsername_textfield.isHidden = false
            jamfProPassword_textfield.isHidden = false
            serverURL_Label.isHidden           = false
            username_label.isHidden            = false
            password_label.isHidden            = false
            saveCreds_button.isHidden          = false
            useApiClient_button.isHidden       = false
        } else if setting == 2 {
            preferredContentSize = CGSize(width: 450, height: 235)
            hideCreds_button.toolTip = "hide username/password fields"
            jamfProServer_textfield.isHidden   = false
            jamfProUsername_textfield.isHidden = false
            jamfProPassword_textfield.isHidden = false
            serverURL_Label.isHidden           = false
            username_label.isHidden            = false
            password_label.isHidden            = false
            saveCreds_button.isHidden          = false
            useApiClient_button.isHidden       = false
        }
        hideCreds_button.state = NSControl.StateValue(rawValue: setting)
        
        hideCreds_button.image = (setting == 0) ? NSImage(named: NSImage.rightFacingTriangleTemplateName):NSImage(named: NSImage.touchBarGoDownTemplateName)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        migrateAppGroupSettings()
        
        header_TextField.stringValue = ""
        header_TextField.wantsLayer = true
        let textFrame = NSTextField(frame: NSRect(x: 0, y: 0, width: 268, height: 1))
        header_TextField.frame = textFrame.frame
        
        setWindowSize(setting: 1)

        jamfProServer_textfield.delegate   = self
        jamfProUsername_textfield.delegate = self
        
        lastServer = userDefaults.string(forKey: "currentServer") ?? ""
        lastUser = userDefaults.string(forKey: "username") ?? ""
        jamfProUsername_textfield.stringValue = lastUser
        print("[viewDidLoad] lastServer: \(lastServer)")
        var foundServer = false
                
        if !FileManager.default.fileExists(atPath: sharedSettingsPlistUrl.path) {
            sharedDefaults!.set(Date(), forKey: "created")
            sharedDefaults!.set([String:AnyObject](), forKey: "serversDict")
        }
        if (sharedDefaults!.object(forKey: "serversDict") as? [String:AnyObject] ?? [:]).count == 0 {
            sharedDefaults!.set(availableServersDict, forKey: "serversDict")
        }
        
        availableServersDict = sharedDefaults!.object(forKey: "serversDict") as? [String:[String:AnyObject]] ?? [:]
        
        
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
            print("removing \(serverName) from the list")
            availableServersDict[serverName] = nil
        }
        if availableServersDict.count > 0 {
            for (displayName, serverInfo) in availableServersDict {
                if displayName != "" && (serverInfo["server"] as! String).prefix(1) != "/" {
                    sortedDisplayNames.append(displayName)
                    if (serverInfo["server"] as! String) == lastServer && lastServer != "" {
                        foundServer = true
                        lastServerDN = displayName
                    }
                } else {
                    availableServersDict[displayName] = nil
                }
            }
            if foundServer {
                selectServer_Button.selectItem(withTitle: lastServer.fqdnFromUrl)
            }
        } else if lastServer != "" {
            availableServersDict[lastServer.fqdnFromUrl] = ["server":lastServer as AnyObject, "date":Date() as AnyObject]
            
            lastServerDN = lastServer.fqdnFromUrl
            sortedDisplayNames.append(lastServerDN)
        }
        
        setSelectServerButton(listOfServers: sortedDisplayNames)
        
        if sortedDisplayNames.firstIndex(of: lastServerDN) != nil {
            selectServer_Button.selectItem(withTitle: lastServerDN)
        } else {
            selectServer_Button.selectItem(withTitle: "")
        }
        
        jamfProServer_textfield.stringValue = lastServer
        saveCreds_button.state    = NSControl.StateValue(userDefaults.integer(forKey: "saveCreds"))
        useApiClient_button.state = NSControl.StateValue(userDefaults.integer(forKey: "useApiClient"))
        setLabels()
        
        if availableServersDict.count != 0 {
            if jamfProServer_textfield.stringValue != "" {
                credentialsCheck()
            }
        } else {
            jamfProServer_textfield.stringValue = ""
            setSelectServerButton(listOfServers: [])
            selectServer_Button.selectItem(withTitle: "Add Server...")
            login_Button.title = "Add"
            selectServer_Action(self)
            setWindowSize(setting: 2)
        }
        if loginAction == "changeServer" {
            quit_Button.title = "Cancel"
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    private func migrateAppGroupSettings() {
        let _sharedContainerUrl     = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.PS2F6S478M.jamfie.SharedJPMA") ?? URL(fileURLWithPath: "/private/tmp")
        let _sharedSettingsPlistUrl = (_sharedContainerUrl.appendingPathComponent("Library/Preferences/group.PS2F6S478M.jamfie.SharedJPMA.plist"))
//        WriteToLog.shared.message("[migrateAppGroupSettings] _sharedSettingsPlistUrl: \(_sharedSettingsPlistUrl.path(percentEncoded: false))")
        
        if !FileManager.default.fileExists(atPath: sharedSettingsPlistUrl.path(percentEncoded: false)) {
            print("[viewDidLoad] creating settings file")
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
//                            WriteToLog.shared.message("[migrateAppGroupSettings] setting value for key: \(key)")
                            print("[migrateAppGroupSettings] setting key: \(key), value: \(value)")
                            sharedDefaults!.set(value, forKey: key)
                        }
                        sharedDefaults!.set("true" as AnyObject, forKey: "migrated")
                        WriteToLog.shared.message("[migrateAppGroupSettings] migrated settings")
                    } catch {
                        WriteToLog.shared.message("[migrateAppGroupSettings] failed to migrate settings")
                        WriteToLog.shared.message("[migrateAppGroupSettings] error: \(error.localizedDescription)")
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

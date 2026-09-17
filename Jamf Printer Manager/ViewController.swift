//
//  Copyright 2026, Jamf
//

import AppKit
import Cocoa
import Foundation
import UniformTypeIdentifiers

class ViewController: NSViewController, SendingLoginInfoDelegate {
    
    @IBOutlet weak var connectedTo_TextField: NSTextField!
    
    @IBAction func changeServer_Action(_ sender: Any) {
        loginAction = "changeServer"
        performSegue(withIdentifier: "loginView", sender: nil)
    }
    
    @IBOutlet weak var existingPrinters_TableView: NSTableView!
    @IBOutlet var existingPrinters_AC: NSArrayController!
    @IBOutlet weak var jamfPrinters_Label: NSTextField!
    
    @IBOutlet var context_Button: NSPopUpButton!
    @IBOutlet var categoryContext_Menu: NSMenu!
    
    
    @IBOutlet weak var categorySubMenu_MenuItem: NSMenuItem!
    
    var selectedPrinterInfo: PrinterInfo?
    var indexOfSelectedPrinter: Int?
    
    @IBOutlet weak var removePrinter_Button: NSButton!
    @IBAction func removePrinter_Action(_ sender: Any) {
        
        removePrinter_Button.isEnabled       = false
        existingPrinters_TableView.isEnabled = false
        let selectedPrinters = existingPrinters_TableView.selectedRowIndexes
        if selectedPrinters.count < 1 {
            _ = Alert.shared.display(header: "Attention:", message: "At least one printer must be selected.", secondButton: "")
            removePrinter_Button.isEnabled       = true
            existingPrinters_TableView.isEnabled = true
        } else {
            print("\(selectedPrinters.count) to be removed")
            var removedPrinters = 0
            var removeMessage = ""
            existingPrintersArray = existingPrinters_AC.arrangedObjects as! [PrinterInfo]
            for selectedIndex in selectedPrinters {
                removeMessage.append("\(existingPrintersArray[selectedIndex].name)\n")
            }
            let oneOrMore = ( selectedPrinters.count == 1 ) ? "printer":"printers"
            let removeReply = Alert.shared.display(header: "Attention:", message: "The following \(oneOrMore) will be removed from Jamf Pro:\n\(removeMessage)", secondButton: "Cancel")
            
            if removeReply == "Cancel" {
                removePrinter_Button.isEnabled       = true
                existingPrinters_TableView.isEnabled = true
            } else {
                var indexSetToArray = [Int]()
                for selectedIndex in selectedPrinters {
                    indexSetToArray.append(selectedIndex)
                }
                indexSetToArray = indexSetToArray.sorted()
                removePrinter(selectedIndex: 0, selectedPrinters: indexSetToArray, removedPrinters: 0)
            }
        }
    }
    
    private func removePrinter(selectedIndex: Int, selectedPrinters: [Int], removedPrinters: Int) {
        var removed   = removedPrinters
        let printerId = existingPrintersArray[selectedPrinters[selectedIndex]].id
        let printerName = existingPrintersArray[selectedPrinters[selectedIndex]].name
        XmlDelegate.shared.apiAction(method: "DELETE", theEndpoint: "printers/id/\(printerId)") { [self]
            (result: (Int,Any)) in

            let (statusCode, httpReply) = result
            if statusCode > 299 {
                WriteToLog.shared.message("Failed to remover printer: \(printerName)")
                WriteToLog.shared.message("              Status code: \(statusCode)")
                WriteToLog.shared.message("                    reply: \(httpReply)")
                if statusCode == 404 {
                    WriteToLog.shared.message("\(printerName) has been removed from \(JamfProServer.destination) since it was not found")
                    existingPrinters_AC.remove(atArrangedObjectIndex: selectedPrinters[selectedIndex]-removedPrinters)
                    existingPrinters_AC.rearrangeObjects()
                }
            } else {
                WriteToLog.shared.message("\(printerName) has been removed from \(JamfProServer.destination)")
                existingPrinters_AC.remove(atArrangedObjectIndex: selectedPrinters[selectedIndex]-removedPrinters)
                existingPrinters_AC.rearrangeObjects()

                removed += 1
            }
            if selectedIndex == selectedPrinters.count-1 {
                existingPrinters_TableView.isEnabled = true
                removePrinter_Button.isEnabled       = true
                existingPrintersArray = existingPrinters_AC.arrangedObjects as! [PrinterInfo]
            } else {
                removePrinter(selectedIndex: selectedIndex+1, selectedPrinters: selectedPrinters, removedPrinters: removed)
            }
        }
    }
        
    @IBOutlet weak var spinner_ProgressIndicator: NSProgressIndicator!
    
    @objc func updateCategory(sender: NSMenuItem) {
        
        let selectedPrinters = existingPrinters_TableView.selectedRowIndexes
            if selectedPrinters.count < 1 {
                _ = Alert.shared.display(header: "Attention:", message: "At least one printer must be selected.", secondButton: "")
            } else {
                var updatedPrinters = 0
                
                var indexSetToArray = [Int]()
                for selectedIndex in selectedPrinters {
                    indexSetToArray.append(selectedIndex)
                }
                indexSetToArray = indexSetToArray.sorted()
                updateCategory_Action(arrayIndex: 0, selectedPrinters: indexSetToArray, selectedCategory: "\(String(describing: sender.title))", updatedPrinters: 0)
            }
    }
    func updateCategory_Action(arrayIndex: Int, selectedPrinters: [Int], selectedCategory: String, updatedPrinters: Int) {
        var updated       = updatedPrinters
        let selectedIndex = selectedPrinters[arrayIndex]

        let printerXML = """
<?xml version="1.0" encoding="UTF-8"?>
<printer>
<category>\(selectedCategory)</category>
</printer>
"""
//        print("printerXML: \(printerXML)")
        let whichPrinter = (existingPrinters_AC.arrangedObjects as! [PrinterInfo])[selectedIndex]
        XmlDelegate.shared.apiAction(method: "PUT", theEndpoint: "printers/id/\(whichPrinter.id)", xmlData: printerXML) { [self]
            (result: (Int,Any)) in
            let (statusCode, _) = result
            if httpSuccess.contains(statusCode) {
                WriteToLog.shared.message("Updated category of printer \(whichPrinter.name) to \(selectedCategory)")
                (existingPrinters_AC.arrangedObjects as! [PrinterInfo])[selectedIndex].category = selectedCategory
                existingPrinters_AC.rearrangeObjects()
            } else {
                WriteToLog.shared.message("Failed (status code: \(statusCode)) to update category of printer \(whichPrinter.name) to \(selectedCategory)")
            }
            updated += 1
            if updated < selectedPrinters.count {
                updateCategory_Action(arrayIndex: arrayIndex + 1, selectedPrinters: selectedPrinters, selectedCategory: selectedCategory, updatedPrinters: updatedPrinters + 1)
            }
        }
    }
    
    fileprivate func fetchCategories() {
        existingPrintersArray = existingPrinters_AC.arrangedObjects as! [PrinterInfo]
        
        XmlDelegate.shared.apiAction(method: "GET", theEndpoint: "categories", acceptFormat: "application/json") { [self]
            (result: (Int,Any)) in
            let (_, allCategories) = result
            listOfCategories.removeAll()
            categoryContext_Menu.removeAllItems()
//            let subMenu = NSMenu()
//            var displayTitle = ""
            var nameIssues = Set<String>()
            
            if let tmpDict = allCategories as? [String:Any] {
                let categoryList = tmpDict["categories"] as! [[String:Any]]
                for theCategory in categoryList {
                    if let categoryName = theCategory["name"] as? String {
                        let trimmedName = categoryName.trimmingCharacters(in: .whitespaces)
                        listOfCategories.append(categoryName)
                        // check for trailing spaces
                        if categoryName != trimmedName {
                            nameIssues.insert(trimmedName)
                        }
                    }
                }
                listOfCategories = listOfCategories.sorted{ $0.localizedCompare($1) == .orderedAscending }
                
                for theCategory in listOfCategories {
                    categoryContext_Menu.addItem(NSMenuItem(title: "\(theCategory)", action: #selector(updateCategory), keyEquivalent: ""))
                }
            }
            
            if nameIssues.count > 0 {
                _ = Alert.shared.display(header: "Attention:", message: "The following categories have leading and/or trailing spaces in their name. This will cause issues if used when uploading a printer.\n\(nameIssues.sorted())", secondButton: "")
            }
            
            NotificationCenter.default.post(name: .loadPrintersNotification, object: self)
            spinner_ProgressIndicator.stopAnimation(self)
        }
    }
    
    func sendLoginInfo(loginInfo: (String,String,String,String,Int)) {
        spinner_ProgressIndicator.startAnimation(self)
        didRun = true
        
        if loginAction != "changeServer" {
            cleanup()
        } else {
            existingPrintersArray.removeAll()
            let tmpArray = existingPrinters_AC.arrangedObjects as! [PrinterInfo]
            let theRange = IndexSet(0..<tmpArray.count)
            existingPrinters_AC.remove(atArrangedObjectIndexes: theRange)
        }

        var saveCredsState: Int?
        (JamfProServer.displayName, JamfProServer.destination, JamfProServer.username, JamfProServer.password,saveCredsState) = loginInfo
        if useApiClient == 0 {
            JamfProServer.tenantId = JamfProServer.destination
        }
        let jamfUtf8Creds = "\(JamfProServer.username):\(JamfProServer.password)".data(using: String.Encoding.utf8)
        JamfProServer.base64Creds = (jamfUtf8Creds?.base64EncodedString())!
        
        WriteToLog.shared.message("----------------------------------------------------------------------------")
        WriteToLog.shared.message("    Jamf Printer Manager: v\(AppInfo.version) Build: \(AppInfo.build)")
        WriteToLog.shared.message("----------------------------------------------------------------------------")
        WriteToLog.shared.message("TelemetryDeck: \(userDefaults.bool(forKey: "optOut") ? "disabled" : "enabled")")
        
        let clientType: String
        switch useApiClient {
        case 0:  clientType = "Platform API"
        case 1:  clientType = "API client/secret"
        case 3:  clientType = "Jamf School (Basic Auth)"
        default: clientType = "username/password"
        }
        WriteToLog.shared.message("Authenticating with \(clientType)")
        let tokenServerUrl = (useApiClient == 0) ? JamfProServer.tenantId : JamfProServer.destination
        TokenDelegate.shared.getToken(serverUrl: tokenServerUrl, base64creds: JamfProServer.base64Creds) { [self]
            authResult in
            let (statusCode,theResult) = authResult
            if theResult == "success" {
                
                if useApiClient == 0 {
                    userDefaults.set(JamfProServer.tenantId, forKey: "lastTenantId")
                    userDefaults.set(JamfProServer.username,  forKey: "lastClientId")
                } else {
                    userDefaults.set(JamfProServer.destination, forKey: "currentServer")
                    userDefaults.set(JamfProServer.username,    forKey: "username")
                }

                let titleSuffix = (useApiClient == 0) ? JamfProServer.displayName : JamfProServer.destination.fqdnFromUrl
                self.view.window?.title = "Jamf Printer Manager: \(titleSuffix)"

                if saveCredsState == 1 {
                    if useApiClient == 0 {
                        Credentials.shared.save(service: JamfProServer.tenantId, account: JamfProServer.username, credential: JamfProServer.password)
                    } else {
                        Credentials.shared.save(service: "\(JamfProServer.destination.fqdnFromUrl)", account: JamfProServer.username, credential: JamfProServer.password)
                    }
                }
                
                jamfPrinters_Label.stringValue = (useApiClient == 3) ? "Jamf School printers" : "Jamf Pro printers"
                if let categoryCol = existingPrinters_TableView.tableColumns.first(where: { $0.headerCell.title == "Category" }) {
                    categoryCol.isHidden = (useApiClient == 3)
                }
                existingPrinters_TableView.doubleAction = (useApiClient == 3) ? nil : #selector(viewSelectObject)
                existingPrinters_TableView.toolTip = (useApiClient == 3) ? nil : "double click a printer to edit"
                removePrinter_Button.isHidden = (useApiClient == 3)

                if useApiClient == 3 {
                    existingPrinters_AC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
                    GetPrintersDelegate.shared.schoolPrinterProfiles { [self] printers in
                        for printer in printers { existingPrinters_AC.addObject(printer) }
                        existingPrinters_AC.rearrangeObjects()
                        NotificationCenter.default.post(name: .loadPrintersNotification, object: self)
                        spinner_ProgressIndicator.stopAnimation(self)
                    }
                    return
                }

                existingPrinters_AC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                GetPrintersDelegate.shared.apiAction(method: "GET", theEndpoint: "printers", acceptFormat: "application/json") { [self]
                    (result: (Int,Data)) in
                    let (statusCode, data) = result
                    do {
                        let printerList = try JSONDecoder().decode(JamfProPrinterList.self, from: data)
                        var fetchedPrinters = 0
                        for thePrinter in printerList.printers {
                            GetPrintersDelegate.shared.apiAction(method: "GET", theEndpoint: "printers/id/\(thePrinter.id)", acceptFormat: "application/json") { [self]
                                (result: (Int,Data)) in
                                let (_, printerDetails) = result
                                fetchedPrinters += 1
                                do {
                                    let jamfProPrinterDetails = try JSONDecoder().decode(JamfProPrinterDetails.self, from: printerDetails)
                                    let printerDetails = jamfProPrinterDetails.printer
                                    existingPrinters_AC.addObject(PrinterInfo(id: "\(printerDetails.id)", name: printerDetails.name.xmlDecode.decodingHTMLEntities(), category: printerDetails.category, uri: printerDetails.uri, cups_name: printerDetails.CUPS_name, location: printerDetails.location, model: printerDetails.model, make_default: "\(printerDetails.make_default)", shared: "\(printerDetails.shared)", info: printerDetails.info, notes: printerDetails.notes, use_generic: "\(printerDetails.use_generic)", ppd: printerDetails.ppd, ppd_contents: printerDetails.ppd_contents, ppd_path: printerDetails.ppd_path, os_req: printerDetails.os_requirements))
                                    existingPrinters_AC.rearrangeObjects()
                                } catch {
                                    WriteToLog.shared.message("Failed to decode printer details for \(thePrinter.name), status code: \(statusCode), error: \(error.localizedDescription)")
                                }
                                
                                if fetchedPrinters == printerList.printers.count {
                                    fetchCategories()
                                }
                            }
                        }
                        if printerList.printers.count == 0 {
                            fetchCategories()
                        }
                    } catch {
                        WriteToLog.shared.message("Failed to fetch/decode all printers, status code: \(statusCode), error: \(error.localizedDescription)")
                    }
                }
            } else {
                DispatchQueue.main.async { [self] in
                    WriteToLog.shared.message("Failed to authenticate, status code: \(statusCode)")
                    performSegue(withIdentifier: "loginView", sender: nil)
                }
            }
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {

        if segue.identifier == "loginView" {
            let loginVC: LoginVC = segue.destinationController as! LoginVC
            loginVC.delegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        TelemetryDeckConfig.optOut = userDefaults.bool(forKey: "optOut")
        
        let logFileURL: URL
        let fileManager = FileManager.default
        let logFileName = getCurrentTime().replacingOccurrences(of: ":", with: "") + "_" + Log.file
        // Get the Logs directory in the app's container
        let logsDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Logs")
        Log.path = logsDirectory.path
        // Create the directory if it doesn't exist
        if !fileManager.fileExists(atPath: Log.path) {
            do {
                try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
                NSLog("[ViewController.viewDidLoad] Created Logs directory at \(logsDirectory)")
            } catch {
                NSLog("[ViewController.viewDidLoad] Failed to create Logs directory: \(error.localizedDescription)")
            }
        }
        
        // Set up the log file URL
        logFileURL = logsDirectory.appendingPathComponent(logFileName)
        Log.filePath = logFileURL.path
        
        // Create the log file if it doesn't exist
        if !fileManager.fileExists(atPath: logFileURL.path) {
            print("[ViewController.viewDidLoad] Create log file: \(logFileURL.path)")
            fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(addedPrintersNotification(_:)), name: .addedPrintersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(returnToLoginNotification(_:)), name: .returnToLoginNotification, object: nil)
        
        let app_support_path = NSHomeDirectory() + "/Library/Application Support"
        if !(FileManager.default.fileExists(atPath: app_support_path)) {
            do {
                try FileManager.default.createDirectory(atPath: app_support_path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                WriteToLog.shared.message("Problem creating '/Library/Application Support' folder:  \(error)")
            }
        }
        
        existingPrinters_TableView.delegate   = self

        existingPrinters_TableView.tableColumns.forEach { (column) in
            column.headerCell.attributedStringValue = NSAttributedString(string: column.title, attributes: [NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 16)])
        }
        existingPrinters_TableView.doubleAction = #selector(viewSelectObject)
        
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = "Jamf Printer Manager"
        
        if showLoginWindow {
            performSegue(withIdentifier: "loginView", sender: nil)
            showLoginWindow = false
        }
    }

    override var representedObject: Any? {
        didSet {

        }
    }
    
    @objc func viewSelectObject() {
        existingPrinters_AC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        existingPrinters_AC.rearrangeObjects()
       

        indexOfSelectedPrinter = existingPrinters_TableView.clickedRow
        
        if indexOfSelectedPrinter ?? -1 < 0 {
            return
        }
        spinner_ProgressIndicator.startAnimation(self)
        existingPrinters_TableView.isEnabled = false
        let selectedPrinter = existingPrintersArray[indexOfSelectedPrinter!]
        let printerId = selectedPrinter.id

        DispatchQueue.main.async {
            
            XmlDelegate.shared.apiAction(method: "GET", theEndpoint: "printers/id/\(printerId)", acceptFormat: "application/json") { [self]
                (result: (Int,Any)) in
                let (statusCode, printerRecord) = result

                guard let printerInfoRecord = printerRecord as? [String:AnyObject] else {
                    WriteToLog.shared.message("[ViewController] Issue reading current printer record.")
                    spinner_ProgressIndicator.stopAnimation(self)
                    _ = Alert.shared.display(header: "", message: "Unable to read the configuration of \(selectedPrinter.name).  \nStatus Code: \(statusCode)", secondButton: "")
                    existingPrinters_TableView.isEnabled = true
                    return
                }
                printerInfoDict = printerInfoRecord["printer"] as! [String:AnyObject]
                
                NotificationCenter.default.addObserver(self, selector: #selector(updatedPrintersNotification(_:)), name: .updatedPrintersNotification, object: nil)
                
                spinner_ProgressIndicator.stopAnimation(self)
                existingPrinters_TableView.isEnabled = true
                self.performSegue(withIdentifier: "printerInfo", sender: nil)
            }
        }
    }
   
    @objc func returnToLoginNotification(_ notification: Notification) {
        let tmpArray = existingPrinters_AC.arrangedObjects as! [PrinterInfo]
        existingPrinters_AC.remove(atArrangedObjectIndexes: IndexSet(0..<tmpArray.count))
        existingPrintersArray.removeAll()
        performSegue(withIdentifier: "loginView", sender: nil)
    }

    @objc func addedPrintersNotification(_ notification: Notification) {
        WriteToLog.shared.message("[ViewController] added \(addedPrinterInfo.count) printer(s)")
       existingPrinters_AC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
       existingPrinters_AC.add(contentsOf: addedPrinterInfo)
       existingPrinters_AC.rearrangeObjects()
       
       existingPrintersArray = existingPrinters_AC.arrangedObjects as! [PrinterInfo]
    }
    @objc func updatedPrintersNotification(_ notification: Notification) {
        
        let tmpArray = existingPrinters_AC.arrangedObjects as! [PrinterInfo]
        let theRange = IndexSet(0..<tmpArray.count)
        existingPrinters_AC.remove(atArrangedObjectIndexes: theRange)
        existingPrinters_AC.add(contentsOf: existingPrintersArray)
    
        NotificationCenter.default.removeObserver(self, name: .updatedPrintersNotification, object: nil)
    }

}

extension ViewController : NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return existingPrintersArray.count
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if existingPrinters_TableView.selectedRowIndexes.count > 0 {
            categorySubMenu_MenuItem.isHidden = false
        } else {
            categorySubMenu_MenuItem.isHidden = true
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
    {
        var newString:String = ""
        if (tableView == existingPrinters_TableView)
        {
            let name = existingPrintersArray[row].name
            newString = "\(name)"
        }
        return newString;
    }
    
}

extension Notification.Name {
    public static let addedPrintersNotification   = Notification.Name("addedPrintersNotification")
    public static let updatedPrintersNotification = Notification.Name("updatedPrintersNotification")
    public static let returnToLoginNotification   = Notification.Name("returnToLoginNotification")
}

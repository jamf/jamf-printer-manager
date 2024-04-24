//
//  Copyright 2023 jamf. All rights reserved.
//

import AppKit
import Cocoa
import Foundation
import UniformTypeIdentifiers

class PrinterInfo: NSObject {
    @objc var id           : String
    @objc var name         : String
    @objc var category     : String
    @objc var uri          : String
    @objc var cups_name    : String
    @objc var location     : String
    @objc var model        : String
    @objc var make_default : String
    @objc var shared       : String
    @objc var info         : String
    @objc var notes        : String
    @objc var use_generic  : String
    @objc var ppd          : String
    @objc var ppd_contents : String
    @objc var ppd_path     : String
    @objc var os_req       : String
    
    init(id: String, name: String, category: String, uri: String, cups_name: String, location: String, model: String, make_default: String, shared: String, info: String, notes: String, use_generic: String, ppd: String, ppd_contents: String, ppd_path: String, os_req: String) {
        self.id           = id
        self.name         = name
        self.category     = category
        self.uri          = uri
        self.cups_name    = cups_name
        self.location     = location
        self.model        = model
        self.make_default = make_default
        self.shared       = shared
        self.info         = info
        self.notes        = notes
        self.use_generic  = use_generic
        self.ppd          = ppd
        self.ppd_contents = ppd_contents
        self.ppd_path     = ppd_path
        self.os_req       = os_req
    }
}

class ViewController: NSViewController, SendingLoginInfoDelegate {
    
    @IBOutlet weak var connectedTo_TextField: NSTextField!
    
    @IBAction func changeServer_Action(_ sender: Any) {
        loginAction = "changeServer"
        performSegue(withIdentifier: "loginView", sender: nil)
    }
    
    @IBOutlet weak var existingPrinters_TableView: NSTableView!
    @IBOutlet var existingPrinters_AC: NSArrayController!
    
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
                WriteToLog.shared.message(stringOfText: "Failed to remover printer: \(printerName)")
                WriteToLog.shared.message(stringOfText: "              Status code: \(statusCode)")
                WriteToLog.shared.message(stringOfText: "                    reply: \(httpReply)")
                if statusCode == 404 {
                    WriteToLog.shared.message(stringOfText: "\(printerName) has been removed from \(JamfProServer.destination) since it was not found")
                    existingPrinters_AC.remove(atArrangedObjectIndex: selectedPrinters[selectedIndex]-removedPrinters)
                    existingPrinters_AC.rearrangeObjects()
                }
            } else {
                WriteToLog.shared.message(stringOfText: "\(printerName) has been removed from \(JamfProServer.destination)")
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
        print("printerXML: \(printerXML)")
        let whichPrinter = (existingPrinters_AC.arrangedObjects as! [PrinterInfo])[selectedIndex]
        XmlDelegate.shared.apiAction(method: "PUT", theEndpoint: "printers/id/\(whichPrinter.id)", xmlData: printerXML) { [self]
            (result: (Int,Any)) in
            let (statusCode, _) = result
            if httpSuccess.contains(statusCode) {
                WriteToLog.shared.message(stringOfText: "Updated category of printer \(whichPrinter.name) to \(selectedCategory)")
                (existingPrinters_AC.arrangedObjects as! [PrinterInfo])[selectedIndex].category = selectedCategory
                existingPrinters_AC.rearrangeObjects()
            } else {
                WriteToLog.shared.message(stringOfText: "Failed (status code: \(statusCode)) to update category of printer \(whichPrinter.name) to \(selectedCategory)")
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
            let subMenu = NSMenu()
            var displayTitle = ""
            
            if let tmpDict = allCategories as? [String:Any] {
                let categoryList = tmpDict["categories"] as! [[String:Any]]
                for theCategory in categoryList {
                    listOfCategories.append(theCategory["name"] as! String)
                }
                listOfCategories = listOfCategories.sorted{ $0.localizedCompare($1) == .orderedAscending }
                
                for theCategory in listOfCategories {
                    categoryContext_Menu.addItem(NSMenuItem(title: "\(theCategory)", action: #selector(updateCategory), keyEquivalent: ""))
                }
            }
            
            NotificationCenter.default.post(name: .loadPrintersNotification, object: self)
            spinner_ProgressIndicator.stopAnimation(self)
        }
    }
    
    func sendLoginInfo(loginInfo: (String,String,String,String,Int)) {
        spinner_ProgressIndicator.startAnimation(self)
        didRun = true
        
        if loginAction != "changeServer" {
            Log.file = getCurrentTime().replacingOccurrences(of: ":", with: "") + "_JamfPrinterManager.log"
            if !(FileManager.default.fileExists(atPath: Log.path! + Log.file)) {
                FileManager.default.createFile(atPath: Log.path! + Log.file, contents: nil, attributes: nil)
            }
            cleanup()
        } else {
            existingPrintersArray.removeAll()
            let tmpArray = existingPrinters_AC.arrangedObjects as! [PrinterInfo]
            let theRange = IndexSet(0..<tmpArray.count)
            existingPrinters_AC.remove(atArrangedObjectIndexes: theRange)
        }

        var saveCredsState: Int?
        (JamfProServer.displayName, JamfProServer.destination, JamfProServer.username, JamfProServer.password,saveCredsState) = loginInfo
        let jamfUtf8Creds = "\(JamfProServer.username):\(JamfProServer.password)".data(using: String.Encoding.utf8)
        JamfProServer.base64Creds = (jamfUtf8Creds?.base64EncodedString())!

        WriteToLog.shared.message(stringOfText: "[ViewController] Running \(AppInfo.name) v\(AppInfo.version)")
        let clientType = ( useApiClient == 0 ) ? "username/password":"API client/secret"
        WriteToLog.shared.message(stringOfText: "Authenticating with \(clientType)")
        TokenDelegate.shared.getToken(serverUrl: JamfProServer.destination, base64creds: JamfProServer.base64Creds) { [self]
            authResult in
            let (statusCode,theResult) = authResult
            if theResult == "success" {
                
                defaults.set(JamfProServer.destination, forKey: "currentServer")
                defaults.set(JamfProServer.username, forKey: "username")
                
                self.view.window?.title = "Jamf Printer Manager: \(JamfProServer.destination.fqdnFromUrl)"
                
                if saveCredsState == 1 {
                    Credentials.shared.save(service: "\(JamfProServer.destination.fqdnFromUrl)", account: JamfProServer.username, credential: JamfProServer.password)
                }
                
                existingPrinters_AC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                XmlDelegate.shared.apiAction(method: "GET", theEndpoint: "printers", acceptFormat: "application/json") { [self]
                    (result: (Int,Any)) in
                    let (statusCode, allPrinters) = result
                    if let printerDict = allPrinters as? [String:Any] {
                        let printerList = printerDict["printers"] as! [[String:Any]]
                        var fetchedPrinters = 0
                        for thePrinter in printerList {
                            let printerId = thePrinter["id"] as! Int
                            let printerName = thePrinter["name"] as! String
                            
                            var acceptFormat = "application/json"
                            XmlDelegate.shared.apiAction(method: "GET", theEndpoint: "printers/id/\(printerId)", xmlData: printerName, acceptFormat: "text/xml") { [self]
                                (result: (Int,Any)) in
                                let (_, printerDetails) = result
                                fetchedPrinters += 1
                                
                                
                                if let data = "\(printerDetails)".data(using: .utf8) {
                                    let xmlParser = XMLParser(data: data)
                                    let delegate = XmlParser()
                                    xmlParser.delegate = delegate
                                    if xmlParser.parse() {
                                        for entry in delegate.printerArray {
                                            existingPrinters_AC.addObject(PrinterInfo(id: entry.id, name: entry.name.xmlDecode, category: entry.category, uri: entry.uri, cups_name: entry.cups_name, location: entry.location, model: entry.model, make_default: entry.make_default, shared: entry.shared, info: entry.info, notes: entry.notes, use_generic: entry.use_generic, ppd: entry.ppd, ppd_contents: entry.ppd_contents, ppd_path: entry.ppd_path, os_req: entry.os_req))
                                        }
                                        existingPrinters_AC.rearrangeObjects()
                                    }
                                    
                                }
                                if fetchedPrinters == printerList.count {
                                    fetchCategories()
                                }
                            }
                        }
                        if printerList.count == 0 {
                            fetchCategories()
                        }
                    }
                }
            } else {
                DispatchQueue.main.async { [self] in
                    WriteToLog.shared.message(stringOfText: "Failed to authenticate, status code: \(statusCode)")
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(addedPrintersNotification(_:)), name: .addedPrintersNotification, object: nil)
        
        let app_support_path = NSHomeDirectory() + "/Library/Application Support"
        if !(FileManager.default.fileExists(atPath: app_support_path)) {
            do {
                try FileManager.default.createDirectory(atPath: app_support_path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                WriteToLog.shared.message(stringOfText: "Problem creating '/Library/Application Support' folder:  \(error)")
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
                    WriteToLog.shared.message(stringOfText: "[ViewController] Issue reading current printer record.")
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
   
    @objc func addedPrintersNotification(_ notification: Notification) {
       print("added \(addedPrinterInfo.count) printer(s)")
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
}

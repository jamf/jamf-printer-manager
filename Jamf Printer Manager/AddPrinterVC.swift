//
//  Copyright 2024, Jamf
//


import Cocoa
import CryptoKit
import Foundation

class AddPrinterVC: NSViewController {
        
    @IBOutlet weak var refresh_Button: NSButton!
    
    @IBAction func refresh_Action(_ sender: Any) {
        let tmpArray = localPrinters_AC.arrangedObjects as! [PrinterInfo]
        let theRange = IndexSet(0..<tmpArray.count)
        localPrinters_AC.remove(atArrangedObjectIndexes: theRange)
        
        let cupsXML = cupsInfo(cupsFileName: printerPlist.path)
        
        processPlist(thePlist: cupsXML, groupingTag: "dict")
        localPrintersArray.removeAll()
        localPrintersArray = localPrinters_AC.arrangedObjects as! [PrinterInfo]
    }
    
    @IBOutlet weak var localPrinters_TableView: NSTableView!
    @IBOutlet weak var category_Button: NSPopUpButton!
    @IBOutlet weak var category_Menu: NSMenu!
    @IBAction func category_Action(_ sender: Any) {
        defaults.set(category_Button.titleOfSelectedItem, forKey: "selectedCategory")
    }
    
    var selectedPrinterArray = [PrinterInfo]()
    
    var local_id           = ""
    var local_name         = ""
    var local_category     = ""
    var local_uri          = ""
    var local_cups_name    = ""
    var local_location     = ""
    var local_model        = ""
    var local_make_default = ""
    var local_use_generic  = ""
    var local_ppd          = ""
    var local_ppd_contents = ""
    var local_ppd_path     = ""
    
    var localPrintersDict = [String:[String:String]]()

    @IBOutlet var localPrinters_AC: NSArrayController!
    
    var localPrintersArray = [PrinterInfo]()
    
    @IBOutlet weak var add_Button: NSButton!
    @IBAction func add_Action(_ sender: Any) {
    
        selectedPrinterArray.removeAll()
        let selectedPrinters = localPrinters_TableView.selectedRowIndexes
        if selectedPrinters.count < 1 {
            _ = Alert.shared.display(header: "Attention:", message: "At least one printer must be selected.", secondButton: "")
        } else {
            add_Button.isEnabled = false
            var addedPrinters = 0
            let selectedCategory = (( category_Button.titleOfSelectedItem == "None" ) ? "":category_Button.titleOfSelectedItem) ?? ""
            localPrintersArray = localPrinters_AC.arrangedObjects as! [PrinterInfo]
            
            var indexSetToArray = [Int]()
            for selectedIndex in selectedPrinters {
                indexSetToArray.append(selectedIndex)
            }
            indexSetToArray = indexSetToArray.sorted()
            addPrinter(arrayIndex: 0, selectedPrinters: indexSetToArray, selectedCategory: selectedCategory, addedPrinters: 0)
            
        }
    }
    
    private func addPrinter(arrayIndex: Int, selectedPrinters: [Int], selectedCategory: String, addedPrinters: Int) {
        var added         = addedPrinters
        var selectedIndex = selectedPrinters[arrayIndex]

        let printerXML = """
<?xml version="1.0" encoding="UTF-8"?>
<printer>
<name>\(localPrintersArray[selectedIndex].name.xmlEncode)</name>
<category>\(String(describing: selectedCategory).xmlEncode)</category>
<uri>\(localPrintersArray[selectedIndex].uri.xmlEncode)</uri>
<CUPS_name>\(localPrintersArray[selectedIndex].cups_name)</CUPS_name>
<location>\(localPrintersArray[selectedIndex].location.xmlEncode)</location>
<model>\(localPrintersArray[selectedIndex].model)</model>
<shared>false</shared>
<info/>
<notes></notes>
<make_default>false</make_default>
<use_generic>false</use_generic>
<ppd>\(localPrintersArray[selectedIndex].ppd)</ppd>
<ppd_path>\(localPrintersArray[selectedIndex].ppd_path)</ppd_path>
<ppd_contents>\(localPrintersArray[selectedIndex].ppd_contents)</ppd_contents>
<os_requirements/>
</printer>
"""
        XmlDelegate.shared.apiAction(method: "POST", theEndpoint: "printers/id/0", xmlData: printerXML) { [self]
            (result: (Int,Any)) in

            let (statusCode, httpReply) = result
                        
            if statusCode > 299 {
                WriteToLog.shared.message(stringOfText: "Error creating \(localPrintersArray[selectedIndex].name).  Status code: \(statusCode)")
                WriteToLog.shared.message(stringOfText: "HTTP reply: \(httpReply)")
                _ = Alert.shared.display(header: "", message: "Error creating \(localPrintersArray[selectedIndex].name).  Status code: \(statusCode)", secondButton: "")

            } else {
                selectedPrinterArray.append(localPrintersArray[selectedIndex])
                let newID = betweenTags(xmlString: httpReply as! String, startTag: "<id>", endTag: "</id>", includeTags: false)
                selectedPrinterArray.last?.id = "\(newID)"
                selectedPrinterArray.last?.category = "\(String(describing: selectedCategory))"
                WriteToLog.shared.message(stringOfText: "\(localPrintersArray[selectedIndex].name) has been added to Jamf Pro.")

                localPrinters_AC.remove(atArrangedObjectIndex: selectedIndex-addedPrinters)
                localPrinters_AC.rearrangeObjects()
                added += 1
            }
            if arrayIndex == selectedPrinters.count-1 {
                add_Button.isEnabled = true
                localPrintersArray = localPrinters_AC.arrangedObjects as! [PrinterInfo]

                addedPrinterInfo = selectedPrinterArray
                NotificationCenter.default.post(name: .addedPrintersNotification, object: nil)
            } else {
                addPrinter(arrayIndex: arrayIndex+1, selectedPrinters: selectedPrinters, selectedCategory: selectedCategory, addedPrinters: added)
            }
        }
    }
    
    private func processPlist(thePlist: String, groupingTag: String) {
//        print("[processPlist] thePlist: \(thePlist)")
//        var localPrintersDict = [String:[String:String]]()
        localPrintersDict.removeAll()
        
        let xmlData = try? Data(contentsOf: URL(filePath: printerPlist.path))
        let xmlParser = XMLParser(data: xmlData ?? Data())

        let delegate = CupsParser()
        xmlParser.delegate = delegate
        if xmlParser.parse() {
            for thePrinter in delegate.printerArray {
                if thePrinter.name != "" {
//                    print("[processPlist] printer name: \(thePrinter.name)")
                    localPrintersDict[thePrinter.name] = ["cups_name" : thePrinter.cups_name, "location" : thePrinter.location, "model" : thePrinter.model, "uri" : thePrinter.uri]
                }
            }
        }
        
        localPrinters_AC.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let ppdDict = ppdInfo(cupsName: "")
        var addToList = true
        for (key, value) in localPrintersDict {
            let local_ppd_info = ppdDict[value["cups_name"]!] ?? [:]
//            print("[processPlist] key: \(key) \t value: \(value)")
//            print("[processPlist] local printer name: \(value["name"] ?? "unknown")")
            
            if let indexOfPrinter = existingPrintersArray.firstIndex(where: { $0.uri == value["uri"] ?? "" }) {
//                print("[processPlist] index of printer: \(indexOfPrinter)")
                let printerPpd = local_ppd_info["ppd_contents"] ?? ""
                
                let localPpdData = Data(printerPpd.xmlDecode.utf8)
                let serverPpdData = Data(existingPrintersArray[indexOfPrinter].ppd_contents.utf8)
//                                print("[processPlist] printerPpd: \(SHA256.hash(data: localPpdData))")
//                                print("[processPlist] existing printer ppd: \(SHA256.hash(data: serverPpdData))")
//                                print("[processPlist] printerPpd: -\(printerPpd.xmlDecode)-")
//                                print("[processPlist] existing printer ppd: -\(existingPrintersArray[indexOfPrinter].ppd_contents)-")
                
//                if existingPrintersArray[indexOfPrinter].ppd_contents == printerPpd.xmlDecode {
                if SHA256.hash(data: localPpdData) == SHA256.hash(data: serverPpdData) {
                    print("[processPlist] skip printer: \(key)")
                    addToList = false
                }
            }
            
            if existingPrintersArray.firstIndex(where: { $0.uri == value["uri"]?.xmlDecode }) != nil && existingPrintersArray.firstIndex(where: { $0.cups_name == value["cups_name"] }) != nil {
                WriteToLog.shared.message(stringOfText: "\(String(describing: value["cups_name"])) is already available in Jamf Pro.")
                addToList = false
            }

            if addToList && value["cups_name"] != nil {
//                let local_ppd_info = ppdDict[value["cups_name"]!] ?? [:]

                if local_ppd_info["ppd_contents"] != nil {
                    localPrinters_AC.addObject(PrinterInfo(id: "", name: key.xmlDecode, category: "", uri: value["uri"] ?? "", cups_name: value["cups_name"] ?? "", location: value["location"]?.xmlDecode ?? "", model: value["model"] ?? "", make_default: "false", shared: value["shared"] ?? "false", info: value["info"]?.xmlDecode ?? "", notes: value["notes"]?.xmlDecode ?? "", use_generic: "false", ppd: local_ppd_info["ppd_file_name"] ?? "", ppd_contents: local_ppd_info["ppd_contents"] ?? "", ppd_path: local_ppd_info["ppd_file_path"] ?? "", os_req: value["os_requirements"] ?? ""))
                } else {
                    print("[processPlist] skip printer, PPD file was not found for: \(key)")
                    WriteToLog.shared.message(stringOfText: "PPD file was not found for \(key)")
                }
            } else {
                print("[processPlist] skip printer: \(key)")
                addToList = true
            }
        }
        localPrinters_AC.rearrangeObjects()
        
    }
    
    private func ppdInfo(cupsName: String) -> [String:[String:String]] {
        
        var ppd_file_path = ""
        var ppd_file_name = ""
        var ppd_contents  = ""
        var ppdDict       = [String:[String:String]]()
        
        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/lpstat")
        process.arguments = ["-lp"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let outputArray = String(decoding: outputData, as: UTF8.self).components(separatedBy: "\n")
            
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(decoding: errorData, as: UTF8.self)
            
            if error != "" {
                WriteToLog.shared.message(stringOfText: "Error running /usr/bin/lpstat -lp \n                \(error)")
            }
            
            var i = 0
            var eof = false
            var currentPrinter = ""
            
            while i < outputArray.count-1 && !eof {
//                print("theLine: \(theLine)")
                let theLineArray = outputArray[i].components(separatedBy: ": ")
                if theLineArray.count > 1 {
//                    print("theLine[1]: \(theLineArray[1])")
                    if localPrintersDict[theLineArray[1]] != nil {
//                        print("found printer: \(theLineArray[1])")
                        currentPrinter = theLineArray[1]
                        while i < outputArray.count-1 && outputArray[i].range(of: "^\\t", options: .regularExpression) != nil {
                            if outputArray[i].range(of: ".ppd$", options: .regularExpression) != nil {
                                let theLineArray2 = outputArray[i].components(separatedBy: ": ")
                                if theLineArray2.count > 1 {
                                    let ppd_file_path = theLineArray2[1]
//                                    print("ppd file: \(ppd_file_path)\n")
                                    if ppd_file_path != "" {
                                        let ppd_url = URL(fileURLWithPath: ppd_file_path)
                                        ppd_file_name = ppd_url.lastPathComponent
                                        
                                        let cups_name = String(ppd_file_name.dropLast(4))
                                        ppd_contents = try String(contentsOf: ppd_url, encoding: .utf8).xmlEncode
                                        if ppd_contents.last == "\n" || ppd_contents == "\r" {
                                            ppd_contents = String(ppd_contents.dropLast())
                                        }
                                        if cups_name != "" {
                                            ppdDict.updateValue(["ppd_file_path" : ppd_file_path, "ppd_contents" : ppd_contents], forKey: cups_name)
                                        }
                                    }
                                }
                            }
                            i += 1
                        }
                    }
                }
                i += 1
            }
        } catch {
            WriteToLog.shared.message(stringOfText: "Error getting ppd info for \(cupsName): \(error.localizedDescription)")
        }

        return ppdDict
    }
    
    private func cupsInfo(cupsFileName: String) -> String {
        
        var cupsPrinters = ""
        
        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/bin/cat")
        process.arguments = [cupsFileName]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            cupsPrinters = String(decoding: outputData, as: UTF8.self)
        } catch {
            WriteToLog.shared.message(stringOfText: "Error reading \(cupsFileName): \(error.localizedDescription)")
        }

        return cupsPrinters
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadPrintersNotification(_:)), name: .loadPrintersNotification, object: nil)
        
        localPrinters_TableView.doubleAction = #selector(addSelectObject)
        
        localPrinters_TableView.delegate   = self
        localPrinters_TableView.tableColumns.forEach { (column) in
            column.headerCell.attributedStringValue = NSAttributedString(string: column.title, attributes: [NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 16)])
        }
    }
    
    @objc func addSelectObject() {
        add_Action(self)
    }
    
    @objc func loadPrintersNotification(_ notification: Notification) {
        loadPrinters()
    }
    
    func loadPrinters() {

        category_Button.removeAllItems()
        category_Button.addItem(withTitle: "None")
        category_Button.addItems(withTitles: listOfCategories)
        category_Menu.insertItem(NSMenuItem.separator(), at: 1)

        var lastCategory = defaults.string(forKey: "selectedCategory") ?? ""
        if lastCategory == "" {
            if category_Button.indexOfItem(withTitle: "Printers") != -1 {
                lastCategory = "Printers"
            } else if category_Button.indexOfItem(withTitle: "printers") != -1 {
                lastCategory = "printers"
            }
        }
        category_Button.selectItem(withTitle: lastCategory)
                
        if FileManager.default.fileExists(atPath: "/Library/Preferences/org.cups.printers.plist") {
                
            let cupsXML = cupsInfo(cupsFileName: printerPlist.path)
            
            if loginAction == "changeServer" {
                refresh_Action(self)
                loginAction = ""
            } else {
                processPlist(thePlist: cupsXML, groupingTag: "dict")
            }
        } else {
            _ = Alert.shared.display(header: "Attention:", message: "No local printers found that can be added to Jamf Pro.", secondButton: "")
        }
        
    }
}

extension AddPrinterVC : NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return localPrintersArray.count
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if localPrinters_TableView.selectedRowIndexes.count > 0 {
            
        }
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
    {
        print("tableView: \(tableView)\t\ttableColumn: \(String(describing: tableColumn))\t\trow: \(row)")
        var newString:String = ""
        if (tableView == localPrinters_TableView)
        {
            let name = localPrintersArray[row].name
            newString = "\(name)"
        }
        return newString;
    }
}

extension Notification.Name {
    public static let loadPrintersNotification = Notification.Name("loadPrintersNotification")
}

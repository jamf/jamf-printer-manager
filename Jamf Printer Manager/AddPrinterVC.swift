//
//  Copyright 2026, Jamf
//


import Cocoa
import CryptoKit
import Foundation

class AddPrinterVC: NSViewController {
    
    let printerManager = PrinterManager()
        
    @IBOutlet weak var refresh_Button: NSButton!
    
    @IBAction func refresh_Action(_ sender: Any) {
        let tmpArray = localPrinters_AC.arrangedObjects as! [PrinterInfo]
        let theRange = IndexSet(0..<tmpArray.count)
        localPrinters_AC.remove(atArrangedObjectIndexes: theRange)
                
        processPlist()
        localPrintersArray.removeAll()
        localPrintersArray = localPrinters_AC.arrangedObjects as! [PrinterInfo]
    }
    
    @IBOutlet weak var localPrinters_TableView: NSTableView!
    @IBOutlet weak var category_Button: NSPopUpButton!
    @IBOutlet weak var category_Menu: NSMenu!
    @IBAction func category_Action(_ sender: Any) {
        userDefaults.set(category_Button.titleOfSelectedItem, forKey: "selectedCategory")
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
//            var addedPrinters = 0
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
        let selectedIndex = selectedPrinters[arrayIndex]

        let printerXML = """
<?xml version="1.0" encoding="UTF-8"?>
<printer>
<name><![CDATA[\(localPrintersArray[selectedIndex].name.xmlEncode)]]></name>
<category>\(selectedCategory.xmlEncode)</category>
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
                WriteToLog.shared.message("Error creating \(localPrintersArray[selectedIndex].name).  Status code: \(statusCode)")
                _ = Alert.shared.display(header: "", message: "Error creating \(localPrintersArray[selectedIndex].name).", secondButton: "")

            } else {
                selectedPrinterArray.append(localPrintersArray[selectedIndex])
                let newID = betweenTags(xmlString: httpReply as! String, startTag: "<id>", endTag: "</id>", includeTags: false)
                selectedPrinterArray.last?.id = "\(newID)"
                selectedPrinterArray.last?.category = "\(String(describing: selectedCategory))"
                WriteToLog.shared.message("\(localPrintersArray[selectedIndex].name) has been added to Jamf Pro.")

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
    
    private func processPlist() {

        localPrintersDict.removeAll()
        var addToList = true
        
        let printers = printerManager.getInstalledPrinters()
        if printers.count == 0 {
            _ = Alert.shared.display(header: "Attention:", message: "No local printers found that can be added to Jamf Pro.", secondButton: "")
            return
        }
        for printer in printers {
            if !(printer.name.isEmpty || printer.cups_name.isEmpty) {
                let ppd_url = URL(fileURLWithPath: printer.ppd_path)
                do {
                    var ppd_contents = try String(contentsOf: ppd_url, encoding: .utf8).xmlEncode
                        if ppd_contents.last == "\n" || ppd_contents == "\r" {
                            ppd_contents = String(ppd_contents.dropLast())
                        }
                    printer.ppd_contents = ppd_contents
                        
                        if let indexOfPrinter = existingPrintersArray.firstIndex(where: { $0.uri == printer.uri }) {
                            let localPpdData = Data(ppd_contents.xmlDecode.utf8)
                            let serverPpdData = Data(existingPrintersArray[indexOfPrinter].ppd_contents.utf8)
                            //                                print("[processPlist] printerPpd: \(SHA256.hash(data: localPpdData))")
                            //                                print("[processPlist] existing printer ppd: \(SHA256.hash(data: serverPpdData))")
                            //                                print("[processPlist] printerPpd: -\(printerPpd.xmlDecode)-")
                            //                                print("[processPlist] existing printer ppd: -\(existingPrintersArray[indexOfPrinter].ppd_contents)-")
                            
                            if SHA256.hash(data: localPpdData) == SHA256.hash(data: serverPpdData) {
                                addToList = false
                            }
                        }
                        
                        if existingPrintersArray.firstIndex(where: { $0.uri == printer.uri.xmlDecode }) != nil && existingPrintersArray.firstIndex(where: { $0.cups_name == printer.cups_name.xmlDecode }) != nil {
                            WriteToLog.shared.message("\(String(describing: printer.cups_name.xmlDecode)) is already available in Jamf Pro.")
                            addToList = false
                        }
                        
                        localPrintersDict[printer.name] = ["cups_name" : printer.cups_name, "location" : printer.location, "model" : printer.model, "uri" : printer.uri, "ppd_path" : printer.ppd_path, "ppd_contents" : printer.ppd_contents]
                } catch {
                    WriteToLog.shared.message("Failed to get ppd ocntents from \(printer.ppd_path). Error: \(error.localizedDescription)")
                }
            }
            
            if addToList && !printer.cups_name.isEmpty {

                if !printer.ppd_contents.isEmpty {
                    localPrinters_AC.addObject(PrinterInfo(id: "", name: printer.name.xmlDecode, category: "", uri: printer.uri.xmlDecode, cups_name: printer.cups_name.xmlDecode, location: printer.location.xmlDecode, model: printer.model, make_default: "false", shared: printer.shared, info: printer.info.xmlDecode, notes: printer.notes.xmlDecode , use_generic: "false", ppd: printer.ppd, ppd_contents: printer.ppd_contents, ppd_path: printer.ppd_path, os_req: printer.os_req))
                } else {
                    WriteToLog.shared.message("PPD file was not found for \(printer.name.xmlDecode)")
                    WriteToLog.shared.message("[processPlist] ppd path: \(printer.ppd_path.xmlDecode)")
                }
            } else {
                addToList = true
            }
        }
        localPrinters_AC.rearrangeObjects()
        
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
            WriteToLog.shared.message("Error reading \(cupsFileName): \(error.localizedDescription)")
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

        var lastCategory = userDefaults.string(forKey: "selectedCategory") ?? ""
        if lastCategory == "" {
            if category_Button.indexOfItem(withTitle: "Printers") != -1 {
                lastCategory = "Printers"
            } else if category_Button.indexOfItem(withTitle: "printers") != -1 {
                lastCategory = "printers"
            }
        }
        category_Button.selectItem(withTitle: lastCategory)
        if loginAction == "changeServer" {
            refresh_Action(self)
            loginAction = ""
        } else {
            processPlist()
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
//        print("tableView: \(tableView)\t\ttableColumn: \(String(describing: tableColumn))\t\trow: \(row)")
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

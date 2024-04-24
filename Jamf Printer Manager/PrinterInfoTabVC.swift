//
//  Copyright 2023 jamf. All rights reserved.
//


import Cocoa
import Foundation
import UniformTypeIdentifiers

protocol UpdatePrinterInfoDelegate {
    func updatedPrinterInfo(newValues: PrinterInfo)
}
var saveEnabled = true

class PrinterInfoTabVC: NSViewController, NSWindowDelegate, NSTextFieldDelegate, NSTextViewDelegate, UpdatePrinterInfoDelegate {
    func updatedPrinterInfo(newValues: PrinterInfo) {
        editPrinterInfo = newValues
    }
    
    
    var delegate: UpdatePrinterInfoDelegate? = nil
    
    var newPrinterArray = [PrinterInfo]()
    var editPrinterInfo = PrinterInfo(id: "", name: "", category: "", uri: "", cups_name: "", location: "", model: "", make_default: "", shared: "", info: "", notes: "", use_generic: "", ppd: "", ppd_contents: "", ppd_path: "", os_req: "")
    
    @IBOutlet weak var displayName_TextField: NSTextField!
    @IBOutlet weak var category_Button: NSPopUpButton!
    @IBOutlet weak var category_Menu: NSMenu!
    
    @IBAction func category_Action(_ sender: NSButton) {
        editPrinterInfo.category = category_Button.titleOfSelectedItem!
    }
    
    @IBOutlet weak var setAsDefault_Button: NSButton!
    @IBAction func setAsDefault_Action(_ sender: NSButton) {
        editPrinterInfo.make_default = "\(sender.state.rawValue)"
    }
    
    @IBOutlet var information_TextView: NSTextView!
    @IBOutlet var notes_TextView: NSTextView!
    @IBOutlet weak var save_Button: NSButton!
    
    @IBOutlet weak var cupsName_TextField: NSTextField!
    @IBOutlet var model_TextField: NSTextField!
    @IBOutlet var location_TextField: NSTextField!
    @IBOutlet var deviceURI_TextField: NSTextField!
        
    @IBOutlet weak var useGenericPPD_Button: NSButton!
    @IBAction func useGenericPPD_Action(_ sender: NSButton) {
        if sender.state.rawValue == 1 {
            ppdPath_TextField.isEnabled = false
            uploadPPD_Button.isEnabled  = false
            ppdPath_TextField.stringValue = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/PrintCore.framework/Resources/Generic.ppd"
            editPrinterInfo.ppd_path          = ppdPath_TextField.stringValue
            let ppdURL                    = URL(string: editPrinterInfo.ppd_path)
            editPrinterInfo.ppd               = ppdURL!.lastPathComponent
            let ppdContents = FileManager.default.contents(atPath: ppdURL!.path)
            editPrinterInfo.ppd_contents = String(decoding: ppdContents!, as: UTF8.self)
        } else {
            ppdPath_TextField.isEnabled = true
            uploadPPD_Button.isEnabled  = true
            ppdPath_TextField.stringValue = printerInfoDict["ppd_path"] as? String ?? ""
            
            editPrinterInfo.ppd = printerInfoDict["ppd"] as? String ?? ""
            editPrinterInfo.ppd_path = printerInfoDict["ppd_path"] as? String ?? ""
            editPrinterInfo.ppd_contents = printerInfoDict["ppd_contents"] as? String ?? ""
        }
        editPrinterInfo.use_generic = "\(sender.state.rawValue)"
    }
    @IBOutlet weak var ppdPath_TextField: NSTextField!
    
    @IBOutlet weak var uploadPPD_Button: NSButton!
    @IBAction func uploadPPD_Action(_ sender: Any) {
        
        let dialog = NSOpenPanel()

        let fileType = UTType(exportedAs: "postscript.driver", conformingTo: .text)

        dialog.title                   = "Select a PPD file";
        dialog.directoryURL            = URL(string: "/private/etc/cups/ppd")
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.allowsMultipleSelection = false
        dialog.allowsOtherFileTypes    = false
        dialog.canChooseFiles          = true
        dialog.canChooseDirectories    = false
        dialog.allowedContentTypes     = [fileType]

        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url 
            
            if (result != nil) {
                let path: String = result!.path
                ppdPath_TextField.stringValue = path
                editPrinterInfo.ppd_path          = path
                editPrinterInfo.ppd               = result!.lastPathComponent
                let ppdContents = FileManager.default.contents(atPath: path)
                editPrinterInfo.ppd_contents = String(decoding: ppdContents!, as: UTF8.self)
            }
        }
    }
        
    @IBOutlet var osRequirement_TextField: NSTextField!
    
    @IBAction func update_Action(_ sender: Any) {
        if saveEnabled {
            saveEnabled = false
            editPrinterInfo.make_default = (editPrinterInfo.make_default == "0") ? "false":"true"
            editPrinterInfo.use_generic  = (editPrinterInfo.use_generic == "0") ? "false":"true"
            editPrinterInfo.category     = ( editPrinterInfo.category == "None" ) ? "":editPrinterInfo.category
            
            let printerXML = """
<?xml version="1.0" encoding="UTF-8"?>
<printer>
    <name>\(editPrinterInfo.name.xmlEncode)</name>
    <category>\(editPrinterInfo.category.xmlEncode)</category>
    <uri>\(editPrinterInfo.uri.xmlEncode)</uri>
    <CUPS_name>\(editPrinterInfo.cups_name.xmlEncode)</CUPS_name>
    <location>\(editPrinterInfo.location.xmlEncode)</location>
    <model>\(editPrinterInfo.model.xmlEncode)</model>
    <shared>\(editPrinterInfo.shared)</shared>
    <info>\(editPrinterInfo.info.xmlEncode)</info>
    <notes>\(editPrinterInfo.notes.xmlEncode)</notes>
    <make_default>\(editPrinterInfo.make_default)</make_default>
    <use_generic>\(editPrinterInfo.use_generic)</use_generic>
    <ppd>\(editPrinterInfo.ppd)</ppd>
    <ppd_path>\(editPrinterInfo.ppd_path)</ppd_path>
    <ppd_contents>\(editPrinterInfo.ppd_contents.xmlEncode)</ppd_contents>
    <os_requirements>\(editPrinterInfo.os_req)</os_requirements>
</printer>
"""

            XmlDelegate.shared.apiAction(method: "PUT", theEndpoint: "printers/id/\(editPrinterInfo.id)", xmlData: printerXML) { [self]
                (result: (Int,Any)) in
                let (statusCode, httpReply) = result
                if statusCode > 299 {
                    print("reply: \(httpReply)")
                    _ = Alert.shared.display(header: "Attention:", message: "Failed to update printer. \nStatus code: \(statusCode)", secondButton: "")
                    WriteToLog.shared.message(stringOfText: "Failed to update \(editPrinterInfo.name)")
                    WriteToLog.shared.message(stringOfText: "Status code: \(statusCode)")
                    NotificationCenter.default.removeObserver(self, name: .updatedPrintersNotification, object: nil)
                } else {
                    WriteToLog.shared.message(stringOfText: "\(editPrinterInfo.name) as been updated")
                    
                    existingPrintersArray = existingPrintersArray.map { $0.id == editPrinterInfo.id ? editPrinterInfo : $0 }
                    NotificationCenter.default.post(name: .updatedPrintersNotification, object: nil)
                }
                saveEnabled = true
                self.view.window?.close()
            }
        }
    }
    
    @IBAction func cancel_Action(_ sender: Any) {
        self.view.window?.close()
    }
    
    
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            switch textField.identifier!.rawValue {
            case "display_name":
                editPrinterInfo.name = displayName_TextField.stringValue
            case "cups_name":
                editPrinterInfo.cups_name = cupsName_TextField.stringValue
            case "model":
                editPrinterInfo.model = model_TextField.stringValue
            case "location":
                editPrinterInfo.location = location_TextField.stringValue
            case "uri":
                editPrinterInfo.uri = deviceURI_TextField.stringValue
            case "ppd_path":
                editPrinterInfo.ppd_path = ppdPath_TextField.stringValue
            case "os_req":
                editPrinterInfo.os_req = osRequirement_TextField.stringValue
            default:
                break
            }
        }
    }
    
    func textDidChange(_ obj: Notification) {
        if let textView = obj.object as? NSTextView {
            switch textView.identifier!.rawValue {
            case "information":
                editPrinterInfo.info = information_TextView.string
            case "notes":
                editPrinterInfo.notes = notes_TextView.string
            default:
                break
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if !EditPrinter.viewDidAppear {

            editPrinterInfo.id = "\(printerInfoDict["id"] as? Int ?? 0)"
            editPrinterInfo.name = (printerInfoDict["name"] as? String ?? "").xmlDecode
            editPrinterInfo.category = printerInfoDict["category"] as? String ?? "None"
            editPrinterInfo.uri = printerInfoDict["uri"] as? String ?? ""
            editPrinterInfo.cups_name = printerInfoDict["CUPS_name"] as? String ?? ""
            editPrinterInfo.location = printerInfoDict["location"] as? String ?? ""
            editPrinterInfo.model = printerInfoDict["model"] as? String ?? ""
            editPrinterInfo.shared = printerInfoDict["shared"] as? String ?? ""
            editPrinterInfo.info = printerInfoDict["info"] as? String ?? ""
            editPrinterInfo.notes = printerInfoDict["notes"] as? String ?? ""
            editPrinterInfo.make_default = "\(printerInfoDict["make_default"] as? Int ?? 0)"
            editPrinterInfo.use_generic = "\(printerInfoDict["use_generic"] as? Int ?? 0)"
            editPrinterInfo.ppd = printerInfoDict["ppd"] as? String ?? ""
            editPrinterInfo.ppd_path = printerInfoDict["ppd_path"] as? String ?? ""
            editPrinterInfo.ppd_contents = printerInfoDict["ppd_contents"] as? String ?? ""
            editPrinterInfo.os_req = printerInfoDict["os_requirements"] as? String ?? ""
            
            EditPrinter.viewDidAppear.toggle()
            
            pendingPrinterInfo = editPrinterInfo
        } else {
            editPrinterInfo = pendingPrinterInfo!
        }
                
        switch self.view.identifier!.rawValue {
        case "general":
            if !EditPrinter.generalDidAppear {
                displayName_TextField.stringValue = editPrinterInfo.name
                
                let setAsDefaultState = NSControl.StateValue(Int(editPrinterInfo.make_default)!)
                setAsDefault_Button.state = NSControl.StateValue(setAsDefaultState.rawValue)
                
                category_Button.removeAllItems()
                category_Button.addItem(withTitle: "None")
                category_Button.addItems(withTitles: listOfCategories)
                category_Menu.insertItem(NSMenuItem.separator(), at: 1)

                if editPrinterInfo.category == "No category assigned" {
                    editPrinterInfo.category = "None"
                }
                category_Button.selectItem(withTitle: editPrinterInfo.category)
                
                information_TextView.string = editPrinterInfo.info
                notes_TextView.string = editPrinterInfo.notes
                
                displayName_TextField.delegate = self
                information_TextView.delegate  = self
                notes_TextView.delegate        = self
                
                EditPrinter.generalDidAppear.toggle()
            }
        case "definition":
            if !EditPrinter.definitionDidAppear {
                cupsName_TextField.stringValue = editPrinterInfo.cups_name
                model_TextField.stringValue = editPrinterInfo.model
                location_TextField.stringValue = editPrinterInfo.location
                deviceURI_TextField.stringValue = editPrinterInfo.uri
                
                let useGenericPpdState = NSControl.StateValue(Int(editPrinterInfo.use_generic)!)
                useGenericPPD_Button.state = NSControl.StateValue(useGenericPpdState.rawValue)
                if useGenericPpdState.rawValue == 1 {
                    ppdPath_TextField.isEnabled = false
                    ppdPath_TextField.stringValue = editPrinterInfo.ppd_path
                } else {
                    ppdPath_TextField.isEnabled = true
                    ppdPath_TextField.stringValue = editPrinterInfo.ppd_path
                }
                
                cupsName_TextField.delegate     = self
                model_TextField.delegate        = self
                location_TextField.delegate     = self
                deviceURI_TextField.delegate    = self
                ppdPath_TextField.delegate      = self
                
                EditPrinter.definitionDidAppear.toggle()
            }
        case "limitations":
            if !EditPrinter.limitationsDidAppear {
                osRequirement_TextField.stringValue = editPrinterInfo.os_req
                
                osRequirement_TextField.delegate = self
                
                EditPrinter.limitationsDidAppear.toggle()
            }
        default:
            break
        }
    }
}

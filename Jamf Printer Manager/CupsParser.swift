//
//  Copyright 2023 jamf. All rights reserved.
//

import Cocoa

class CupsParser: NSObject, XMLParserDelegate {
    
    var printerArray: [Printer] = []
    var keyName: String         = ""
    var keyFound: Bool          = false
    var readValue: Bool         = false
    
    enum Tag { case none, dict, key, string, integer, array, bool }
    var tag: Tag = .none
    
//    enum State { case none, name, queue, uri, cups_name, location }
//    var state: State = .none
    var newPrinter: Printer? = nil
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
//        print("elementName: \(elementName)")
        switch elementName {
        case "dict":
            self.newPrinter = Printer()
//            self.state = .none
            self.tag   = .none
        case "key":
            self.tag = .key
            keyFound = false
            keyName = ""
        case "string":
            self.tag = .string
            readValue = true
        case "integer":
            self.tag = .string
            readValue = true
        case "array":
            self.tag = .array
        case "true", "false":
            self.tag = .bool
        default:
            keyFound = false
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if let newPrinter = self.newPrinter, elementName == "dict" {
            self.printerArray.append(newPrinter)
            self.newPrinter = nil
//            keyFound = false
        } else if let newPrinter = self.newPrinter, elementName == "key" {
            keyFound = true
        } else if let newPrinter = self.newPrinter {
            keyName = ""
            readValue = false
        }
        
//        self.state = .none
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let _ = self.newPrinter else { return }
//        print("            keyName: \(keyName)")
//        print("    foundCharacters: \(string)")
        if !keyFound {
            keyName = string
        } else {
//            if string != "\n\t\t" {
            if readValue {
                switch keyName {
                case "printer-name":    // cups_name
                    self.newPrinter!.cups_name += string
                case "printer-info":    // printer name
//                    print("string: '\(string)'")
                    self.newPrinter!.name += string
                case "printer-location":
                    self.newPrinter!.location = string
                case "device-uri":
                    self.newPrinter!.uri += string
                case "printer-make-and-model":
                    self.newPrinter!.model = string
                default:
                    break
                }
            }
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
    }
}

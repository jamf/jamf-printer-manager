//
//  Copyright 2026, Jamf
//

import Foundation

class PrinterManager {
    
    func getInstalledPrinters() -> [PrinterInfo] {
        var printers: [PrinterInfo] = []
        var dests: UnsafeMutablePointer<cups_dest_t>?
        
        let numDests = cupsGetDests2(nil, &dests)
        
        guard numDests > 0, let destinations = dests else {
            return printers
        }
        
        for i in 0..<Int(numDests) {
            var dest = destinations[i]
            let name = String(cString: dest.name)
//            let isDefault = dest.is_default != 0
            
            // Get destination info using the modern API
            let destInfo = cupsCopyDestInfo(nil, &dest)
            
            // Get printer attributes using cupsGetOption
            let makeAndModel = getOption("printer-make-and-model", from: dest) ?? ""
            let info = getOption("printer-info", from: dest) ?? ""
            let location = getOption("printer-location", from: dest) ?? ""
            let uri = getOption("device-uri", from: dest)
            
            // Check for PPD in standard location
            // Modern printers may not have PPDs (driverless/AirPrint)
            let standardPPDPath = "/etc/cups/ppd/\(name).ppd"
            let ppdPath = (FileManager.default.fileExists(atPath: standardPPDPath)
                           ? standardPPDPath
                           : nil) ?? ""
            
            let printer = PrinterInfo(
                id: "",
                name: info,
                category: "",
                uri: uri ?? "",
                cups_name: name,
                location: location,
                model: makeAndModel,
                make_default: "false",
                shared: "false",
                info: "",
                notes: "",
                use_generic: "false",
                ppd: "",
                ppd_contents: "",
                ppd_path: ppdPath,
                os_req: ""
            )
            printers.append(printer)
            
            if destInfo != nil {
                cupsFreeDestInfo(destInfo)
            }
        }
        
        cupsFreeDests(numDests, dests)
        
        return printers
    }
    
    private func getOption(_ option: String, from dest: cups_dest_t) -> String? {
        guard let value = cupsGetOption(option, dest.num_options, dest.options) else {
            return nil
        }
        return String(cString: value)
    }
    
    // Get detailed info about a specific printer's capabilities
    func getPrinterCapabilities(printerName: String) -> [String: String] {
        var capabilities: [String: String] = [:]
        var dests: UnsafeMutablePointer<cups_dest_t>?
        
        let numDests = cupsGetDests2(nil, &dests)
        
        guard numDests > 0, let destinations = dests else {
            return capabilities
        }
        
        defer {
            cupsFreeDests(numDests, dests)
        }
        
        // Find the specific printer
        guard let destPtr = cupsGetDest(printerName, nil, numDests, destinations) else {
            return capabilities
        }
        
        var dest = destPtr.pointee
        
        // Get destination info
        guard let destInfo = cupsCopyDestInfo(nil, &dest) else {
            return capabilities
        }
        
        defer {
            cupsFreeDestInfo(destInfo)
        }
        
        // Query specific IPP attributes
        let attributes = [
            "printer-make-and-model",
            "printer-location",
            "printer-info",
            "device-uri",
            "printer-state",
            "printer-state-reasons",
            "printer-uri-supported",
            "media-supported",
            "sides-supported",
            "print-color-mode-supported"
        ]
        
        for attr in attributes {
            if let value = getOption(attr, from: dest) {
                capabilities[attr] = value
            }
        }
        
        return capabilities
    }
    
    // Check if printer supports a specific media size
    func printerSupportsMedia(_ mediaName: String, printerName: String) -> Bool {
        var dests: UnsafeMutablePointer<cups_dest_t>?
        let numDests = cupsGetDests2(nil, &dests)
        
        guard numDests > 0,
              let destinations = dests,
              let destPtr = cupsGetDest(printerName, nil, numDests, destinations) else {
            return false
        }
        
        defer {
            cupsFreeDests(numDests, dests)
        }
        
        var dest = destPtr.pointee
        
        guard let destInfo = cupsCopyDestInfo(nil, &dest) else {
            return false
        }
        
        defer {
            cupsFreeDestInfo(destInfo)
        }
        
        // Check media support
        let supported = cupsCheckDestSupported(
            nil,
            &dest,
            destInfo,
            CUPS_MEDIA,
            mediaName
        )
        
        return supported == 1
    }
    
    func printPrinterDetails() {
        let printers = getInstalledPrinters()
        
        if printers.isEmpty {
            print("No printers found.")
            return
        }
        
        for printer in printers {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("CUPS Printer: \(printer.cups_name)")
//            print("Default: \(printer.isDefault ? "Yes" : "No")")
            
//            if let info = printer.info {
                print("Friendly name: \(printer.name)")
//            }
//            if let model = printer.model {
                print("Make/Model: \(printer.model)")
//            }
//            if let location = printer.location {
                print("Location: \(printer.location)")
//            }
//            if let uri = printer.uri {
                print("URI: \(printer.uri)")
//            }
            if !printer.ppd_path.isEmpty {
                print("PPD Path: \(printer.ppd_path)")
            } else {
                print("PPD: Not available (driverless/IPP Everywhere printer)")
            }
        }
    }
}

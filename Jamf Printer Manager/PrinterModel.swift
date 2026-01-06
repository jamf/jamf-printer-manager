//
//  Copyright 2026, Jamf
//

import Foundation

struct JamfProPrinterList: Codable {
    let printers: [JamfProPrinter]
}

struct JamfProPrinter: Codable {
    let id: Int
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        let rawName = try container.decode(String.self, forKey: .name)
        name = rawName.decodingHTMLEntities()
    }
}

// MARK: - JamfProPrinterDetails
struct JamfProPrinterDetails: Codable {
    let printer: PrinterDetail
}

// MARK: - Printer
struct PrinterDetail: Codable {
    let id: Int
    let name, category, uri, CUPS_name: String
    let location, model: String
    let shared: Bool
    let info, notes: String
    let make_default, use_generic: Bool
    let ppd, ppd_contents, ppd_path, os_requirements: String

    enum CodingKeys: String, CodingKey {
        case id, name, category, uri
        case CUPS_name
        case location, model, shared, info, notes
        case make_default
        case use_generic
        case ppd
        case ppd_contents
        case ppd_path
        case os_requirements
    }
}

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
 

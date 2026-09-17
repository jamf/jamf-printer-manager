//
//  Copyright 2026, Jamf
//

import Foundation

// Handles both Classic API {"printers":[...]} and Platform API {"results":[...],"totalCount":N}
struct JamfProPrinterList: Decodable {
    let printers: [JamfProPrinter]

    enum CodingKeys: String, CodingKey { case printers, results }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try? container.decode([JamfProPrinter].self, forKey: .printers) {
            printers = list
        } else {
            printers = (try? container.decode([JamfProPrinter].self, forKey: .results)) ?? []
        }
    }
}

struct JamfProPrinter: Decodable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey { case id, name }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        let rawName = try container.decode(String.self, forKey: .name)
        name = rawName.decodingHTMLEntities()
    }
}

// Handles both Classic API {"printer":{...}} wrapper and Platform API direct object
struct JamfProPrinterDetails: Decodable {
    let printer: PrinterDetail

    enum CodingKeys: String, CodingKey { case printer }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let p = try? container.decode(PrinterDetail.self, forKey: .printer) {
            printer = p
        } else {
            printer = try PrinterDetail(from: decoder)
        }
    }
}

// Handles Classic API (underscore names) and Platform API (camelCase names)
struct PrinterDetail: Decodable {
    let id: Int
    let name, category, uri, CUPS_name: String
    let location, model: String
    let shared: Bool
    let info, notes: String
    let make_default, use_generic: Bool
    let ppd, ppd_contents, ppd_path, os_requirements: String

    enum CodingKeys: String, CodingKey {
        case id, name, category, uri, location, model, shared, info, notes, ppd
        case CUPS_name, cupsName
        case make_default, makeDefault
        case use_generic, useGeneric
        case ppd_contents, ppdContents
        case ppd_path, ppdPath
        case os_requirements, osRequirements
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(Int.self, forKey: .id)
        name            = (try? c.decode(String.self, forKey: .name))            ?? ""
        category        = (try? c.decode(String.self, forKey: .category))        ?? ""
        uri             = (try? c.decode(String.self, forKey: .uri))             ?? ""
        CUPS_name       = (try? c.decode(String.self, forKey: .CUPS_name))       ?? (try? c.decode(String.self, forKey: .cupsName))       ?? ""
        location        = (try? c.decode(String.self, forKey: .location))        ?? ""
        model           = (try? c.decode(String.self, forKey: .model))           ?? ""
        shared          = (try? c.decode(Bool.self,   forKey: .shared))          ?? false
        info            = (try? c.decode(String.self, forKey: .info))            ?? ""
        notes           = (try? c.decode(String.self, forKey: .notes))           ?? ""
        make_default    = (try? c.decode(Bool.self,   forKey: .make_default))    ?? (try? c.decode(Bool.self, forKey: .makeDefault))    ?? false
        use_generic     = (try? c.decode(Bool.self,   forKey: .use_generic))     ?? (try? c.decode(Bool.self, forKey: .useGeneric))     ?? false
        ppd             = (try? c.decode(String.self, forKey: .ppd))             ?? ""
        ppd_contents    = (try? c.decode(String.self, forKey: .ppd_contents))    ?? (try? c.decode(String.self, forKey: .ppdContents))    ?? ""
        ppd_path        = (try? c.decode(String.self, forKey: .ppd_path))        ?? (try? c.decode(String.self, forKey: .ppdPath))        ?? ""
        os_requirements = (try? c.decode(String.self, forKey: .os_requirements)) ?? (try? c.decode(String.self, forKey: .osRequirements)) ?? ""
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

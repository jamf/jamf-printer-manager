//
//  Copyright 2023 jamf. All rights reserved.
//

import Cocoa
import Foundation


var addedPrinterInfo        = [PrinterInfo]()
var bookmarkError           = false
var listOfCategories        = [String]()
var didRun                  = false
let defaults                = UserDefaults.standard
var existingPrintersArray   = [PrinterInfo]()
var pendingPrinterInfo: PrinterInfo?
//var existingPrintersDict    = [String:[String:String]]()
var printerToUpdate         = [String:String]()
let httpSuccess             = 200...299
var loginAction             = ""
var printerInfoDict         = [String:AnyObject]()
let printerPlist            = URL(fileURLWithPath: "/Library/Preferences/org.cups.printers.plist")
let refreshInterval: UInt32 = 25*60 // 25 minutes
var runComplete             = false
var showLoginWindow         = true
var tokenTimeCreated: Date?
var defaultTextColor        = isDarkMode ? NSColor.white:NSColor.black

// for saving servers, shared settings - LoginVC
var saveServers            = true
var maxServerList          = 40
var appsGroupId            = "group.PS2F6S478M.jamfie.SharedJPMA"
let sharedDefaults         = UserDefaults(suiteName: appsGroupId)
let sharedContainerUrl     = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appsGroupId)
let sharedSettingsPlistUrl = (sharedContainerUrl?.appendingPathComponent("Library/Preferences/\(appsGroupId).plist"))!
var useApiClient           = 0

// determine if we're using dark mode
var isDarkMode: Bool {
    let mode = defaults.string(forKey: "AppleInterfaceStyle")
    return mode == "Dark"
}

class Bookmark: NSObject, NSCoding {
    var theData: [URL: Data]
    
    required init(coder aDecoder: NSCoder) {
        theData = aDecoder.decodeObject(forKey: "theData") as? [URL: Data] ?? [:]
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(theData, forKey: "theData")
    }
}

struct AppInfo {
    static let bookmarksPath   = NSHomeDirectory() + "/Library/Application Support/bookmarks"
    static let dict    = Bundle.main.infoDictionary!
    static let version = dict["CFBundleShortVersionString"] as! String
    static let build   = dict["CFBundleVersion"] as! String
    static let name    = dict["CFBundleName"] as! String

    static let userAgentHeader = "\(String(describing: name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!))/\(AppInfo.version)"
    
    static var clientLogo = [NSImage(named: "loginLogo"), NSImage(named: "loginLogo-lt")]
    
    static var bundlePath = Bundle.main.bundleURL
    static var iconFile   = bundlePath.appendingPathComponent("/Resources/AppIcon.icns")
    static let appSupport       = NSHomeDirectory() + "/Library/Application Support"
    
    static var startTime        = Date()
}

struct EditPrinter {
    static var viewDidAppear        = false
    static var generalDidAppear     = false
    static var definitionDidAppear  = false
    static var limitationsDidAppear = false
}

struct JamfProServer {
    static var csa           = true // cloud services connection
    static var displayName   = ""
    static var majorVersion  = 0
    static var minorVersion  = 0
    static var patchVersion  = 0
    static var build         = ""
    static var version       = ""
    static var authType      = "Basic"
    static var destination   = ""
    static var username      = ""
    static var password      = ""
//    static var userpass      = ""
    static var accessToken   = ""
    static var authCreds     = ""
    static var authExpires   = 30.0
    static var base64Creds   = ""        // used if we want to auth with a different account
    static var currentCred   = ""
    static var pkgsNotFound  = 0
    static var validToken    = false
    static var tokenCreated  = Date()
//    static var tokenExpires  = ""
    static var saveCreds     = 0
    static var sessionCookie = [HTTPCookie]()
    static var stickySession = true
    static var url           = ""
    static var useApiClient  = 0
}

struct Log {
//    static var path: String? = (NSHomeDirectory() + "/Library/Logs/JamfPrinterManager/")
    static var path: String? = (NSHomeDirectory() + "/Library/Logs/")
    static var file:  String = ""
    static var file_FH: FileHandle? = FileHandle(forUpdatingAtPath: "")
    static var maxFiles      = 42
}

struct Token {
    static var refreshInterval:UInt32 = 20*60  // 20 minutes
    static var sourceServer  = ""
    static var sourceExpires = ""
}

public func fetchBookmark() -> String {
   var bookmarkedString = ""
   if FileManager.default.fileExists(atPath: AppInfo.bookmarksPath) {
       do {
           var isStale = false
           let data = try Data(contentsOf: NSURL(fileURLWithPath: AppInfo.bookmarksPath) as URL)
           let theURL = try URL(
               resolvingBookmarkData: data,
               options: .withSecurityScope,
               relativeTo: nil,
               bookmarkDataIsStale: &isStale
           )
           
           if isStale {
               print("bookmark is stale")
               storeBookmark(theURL: theURL)
           }
           _ = theURL.startAccessingSecurityScopedResource()

           bookmarkedString = theURL.absoluteString
       } catch {
           print("Error resolving bookmark:", error)
           bookmarkError = true
//            return localRecipeUrl
       }
   } else {
       
   }
//   print("bookmarkedURL!: \(bookmarkedString)")
   return bookmarkedString
}

public func storeBookmark(theURL: URL) {
   do {
       print("[\(#line)-storeBookmark] store \(theURL) in \(AppInfo.bookmarksPath)")
       // use for saving folder as bookmark
//       let bookmarkArchive     = try theURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
       if FileManager.default.fileExists(atPath: AppInfo.bookmarksPath) {
           do {
               try FileManager.default.removeItem(atPath: AppInfo.bookmarksPath)
           } catch {
               WriteToLog.shared.message(stringOfText: "Failed to reset \(AppInfo.bookmarksPath)")
           }
       }
       let bookmarkArchive     = try theURL.bookmarkData(options: .securityScopeAllowOnlyReadAccess, includingResourceValuesForKeys: nil, relativeTo: nil)
       print("[Global] bookmarkArchive: \(bookmarkArchive)")
       try bookmarkArchive.write(to: NSURL(fileURLWithPath: AppInfo.bookmarksPath) as URL)
       
   } catch let error as NSError {
       bookmarkError = true
       WriteToLog.shared.message(stringOfText: "[Global] set bookmark Failed: \(error.description)\n")
   }
}

func timeDiff(startTime: Date) -> (Int, Int, Int, Double) {
    let endTime = Date()
    let components = Calendar.current.dateComponents([
        .hour, .minute, .second, .nanosecond], from: startTime, to: endTime)
    var diffInSeconds = Double(components.hour!)*3600 + Double(components.minute!)*60 + Double(components.second!) + Double(components.nanosecond!)/1000000000
    diffInSeconds = Double(round(diffInSeconds * 1000) / 1000)
    return (Int(components.hour!), Int(components.minute!), Int(components.second!), diffInSeconds)
}

// get current time
func getCurrentTime(theFormat: String = "") -> String {
    var stringDate = ""
    let current = Date()
    let localCalendar = Calendar.current
    let dateObjects: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let dateTime = localCalendar.dateComponents(dateObjects, from: current)
    let currentMonth  = dd(value: dateTime.month!)
    let currentDay    = dd(value: dateTime.day!)
    let currentHour   = dd(value: dateTime.hour!)
    let currentMinute = dd(value: dateTime.minute!)
    let currentSecond = dd(value: dateTime.second!)
    switch theFormat {
    case "info":
        stringDate = "\(dateTime.year!)-\(currentMonth)-\(currentDay) \(currentHour)\(currentMinute)"
    default:
        stringDate = "\(dateTime.year!)\(currentMonth)\(currentDay)_\(currentHour)\(currentMinute)\(currentSecond)"
    }
    return stringDate
}

// add leading zero to single digit integers
func dd(value: Int) -> String {
    let formattedValue = (value < 10) ? "0\(value)":"\(value)"
    return formattedValue
}


func formattedText() -> NSAttributedString {
//    let basicFont = NSFont.systemFont(ofSize: 12)
//    let basicAttributes = [NSAttributedString.Key.font: basicFont, .foregroundColor: defaultTextColor]
//    let aboutString = NSMutableAttributedString(string: supportText, attributes: basicAttributes)
//    
//    let warningString = NSMutableAttributedString(string: agreementText, attributes: basicAttributes as [NSAttributedString.Key : Any])
//    aboutString.append(warningString)
//    
//    let agreementString = NSAttributedString(string: agreementText, attributes: basicAttributes)
//    aboutString.append(agreementString)
//
//    return aboutString
    let licenseText      = """
    Jamf Printer Manager helps upload printer configurations to Jamf Pro. This software is licensed under the terms of Jamf's Software License and Services Agreement.

    Copyright 2024, Jamf Software, LLC.
    """
    
    let theFont           = NSFont.systemFont(ofSize: 12)
    let licenseAttributes = [NSAttributedString.Key.font: theFont, .foregroundColor: defaultTextColor]
    let licenseString     = NSMutableAttributedString(string: licenseText, attributes: licenseAttributes as [NSAttributedString.Key : Any])
    let foundRange        = licenseString.mutableString.range(of: "Jamf's Software License and Services Agreement")
    if foundRange.location != NSNotFound {
        licenseString.addAttribute(NSAttributedString.Key.link, value: "https://resources.jamf.com/documents/jamf-SLASA.pdf", range: foundRange)
    }
    return licenseString
}


extension String {
    var fqdnFromUrl: String {
        get {
            var fqdn = ""
            let nameArray = self.components(separatedBy: "://")
            if nameArray.count > 1 {
                fqdn = nameArray[1]
            } else {
                fqdn =  self
            }
            if fqdn.contains(":") {
                let fqdnArray = fqdn.components(separatedBy: ":")
                fqdn = fqdnArray[0]
            }
            if fqdn.last == "/" {
                fqdn = "\(fqdn.dropLast(1))"
            }
            return fqdn
        }
    }
    var xmlDecode: String {
        get {
            let newString = self.replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&apos;", with: "'")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
            let data = newString.data(using: .utf8)
            if String(data: data!, encoding: .nonLossyASCII) != nil {
                return String(data: data!, encoding: .nonLossyASCII)!
            } else {
                return newString
            }
        }
    }
    var xmlEncode: String {
        get {
            var newString = self
            newString = newString.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "'", with: "&#39;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
//            let data = newString.data(using: .nonLossyASCII, allowLossyConversion: true)!
//            return String(data: data, encoding: .utf8)!
            return newString
        }
    }
    var urlFix: String {
        get {
            var fixedUrl = self.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
            fixedUrl     = fixedUrl.replacingOccurrences(of: "//api", with: "/api")
            fixedUrl     = fixedUrl.replacingOccurrences(of: "/?failover", with: "")
            return fixedUrl
        }
    }
    var urlToFqdn: String {
        // includes port
        get {
            var fqdn = self
            if fqdn != "" {
                fqdn = fqdn.replacingOccurrences(of: "http://", with: "")
                fqdn = fqdn.replacingOccurrences(of: "https://", with: "")
                let fqdnArray = fqdn.split(separator: "/")
                fqdn = "\(fqdnArray[0])"
            }
            return fqdn
        }
    }
}

// extract the value between (different) tags - start
func betweenTags(xmlString:String, startTag:String, endTag:String, includeTags: Bool) -> String {
    var rawValue = ""
    if let start = xmlString.range(of: startTag),
        let end  = xmlString.range(of: endTag, range: start.upperBound..<xmlString.endIndex) {
        rawValue.append(String(xmlString[start.upperBound..<end.lowerBound]))
    }
    if includeTags {
        return "\(startTag)\n\(rawValue)\n\(endTag)"
    } else {
        return rawValue
    }
}
//  extract the value between (different) tags - end

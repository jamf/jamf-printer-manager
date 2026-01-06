//
//  Copyright 2026, Jamf
//

import Cocoa
import Foundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBAction func showAbout(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let aboutWindowController = storyboard.instantiateController(withIdentifier: "aboutWC") as! NSWindowController
        if !windowIsVisible(windowName: "About") {
            aboutWindowController.window?.hidesOnDeactivate = false
            aboutWindowController.showWindow(self)
        } else {
            let windowsCount = NSApp.windows.count
            for i in (0..<windowsCount) {
                if NSApp.windows[i].title == "About" {
                    NSApp.windows[i].makeKeyAndOrderFront(self)
                    break
                }
            }
        }
    }
    @IBAction func showHelp(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let helpWindowController = storyboard.instantiateController(withIdentifier: "help") as! NSWindowController
        if !windowIsVisible(windowName: "Help") {
            helpWindowController.window?.hidesOnDeactivate = false
            helpWindowController.showWindow(self)
        } else {
            let windowsCount = NSApp.windows.count
            for i in (0..<windowsCount) {
                if NSApp.windows[i].title == "Help" {
                    NSApp.windows[i].makeKeyAndOrderFront(self)
                    break
                }
            }
        }
    }
    func windowIsVisible(windowName: String) -> Bool {
        let options = CGWindowListOption(arrayLiteral: CGWindowListOption.excludeDesktopElements, CGWindowListOption.optionOnScreenOnly)
        let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        let infoList = windowListInfo as NSArray? as? [[String: AnyObject]]
        for item in infoList! {
            if let _ = item["kCGWindowOwnerName"], let _ = item["kCGWindowName"] {
                if "\(item["kCGWindowOwnerName"]!)" == "Jamf Printer Manager" && "\(item["kCGWindowName"]!)" == windowName {
                    return true
                }
            }
        }
        return false
    }
    
    @IBAction func showLogFolder(_ sender: Any) {
        if (FileManager.default.fileExists(atPath: Log.path)) {
            NSWorkspace.shared.open(URL(fileURLWithPath: Log.path))
        } else {
            _ = Alert.shared.display(header: "Alert", message: "There are currently no log files to display.", secondButton: "")
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        configureTelemetryDeck()
    }

    func applicationWillTerminate(_ aNotification: Notification) {

    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true
    }

}


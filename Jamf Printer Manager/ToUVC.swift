//
//  Copyright 2026, Jamf
//

import Cocoa

class ToUVC: NSViewController {
    var window: NSWindow?

    @IBOutlet weak var icon_ImageView: NSImageView!
    
    @IBOutlet weak var termsOfUse: NSTextField!
    
    @IBOutlet weak var exit_Button: NSButton!
    @IBOutlet weak var accept_Button: NSButton!
    
    @objc func interfaceModeChanged(sender: NSNotification) {
        setTheme(darkMode: isDarkMode)
    }
    func setTheme(darkMode: Bool) {
        self.view.layer?.backgroundColor = darkMode ? CGColor.init(gray: 0.2, alpha: 1.0):CGColor.init(gray: 0.2, alpha: 0.2)
        defaultTextColor = isDarkMode ? NSColor.white:NSColor.black

        termsOfUse.attributedStringValue = formattedText()
    }
    
    
    @IBAction func exitOrAccept(_ sender: NSButton) {
        DistributedNotificationCenter.default.removeObserver("AppleInterfaceThemeChangedNotification")
        if sender.title != "Accept" {
            userDefaults.set(0, forKey: "shouldShowAgreement")
            exit(1)
        } else {
            userDefaults.set(1, forKey: "shouldShowAgreement")
            dismiss(self)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(interfaceModeChanged(sender:)), name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil)
        
        icon_ImageView.image = NSImage(named: "AppIcon")
        exit_Button.title = "Exit"
        accept_Button.title = "Accept"
        
        termsOfUse.attributedStringValue = formattedText()
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        self.view.wantsLayer = true
        setTheme(darkMode: isDarkMode)
        
        window = self.view.window!
        window?.titleVisibility = .hidden
        window?.titlebarAppearsTransparent = true
        window?.styleMask = .fullSizeContentView
        window?.styleMask.remove(.closable)
        window?.styleMask.remove(.miniaturizable)
        window?.styleMask.remove(.fullScreen)
        window?.styleMask.remove(.resizable)
    }
    
}


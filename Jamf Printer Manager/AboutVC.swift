//
//  Copyright 2026, Jamf
//

import AppKit
import Cocoa
import Foundation

class AboutVC: NSViewController {
    
    @IBOutlet weak var optOut_button: NSButton!
    
    @IBAction func optOut_action(_ sender: NSButton) {
        userDefaults.set(sender.state == .on, forKey: "optOut")
        TelemetryDeckConfig.optOut = (sender.state == .on)
    }
    
    let supportText = """
    The Jamf Printer Manager application uploads local printer configuration to Jamf Pro.
    
    By default the app sends basic hardware, OS, and usage data for the app. Data is sent anonymously to https://telemetrydeck.com and used to aid in application development. To disable the sending of data click the 'Opt out of analytics' below.

    """

    let feedback = """

    Please share feedback by filing an issue.

    """

    let warningText = """

    Warning: Failure to test Jamf Printer Manager thoroughly on non production devices could result in printer misconfigurations on production devices.

    """

    let agreementText = """
        
    This software is licensed under the terms of the Jamf Concepts Use Agreement

    Copyright xxxx, Jamf Software, LLC.
    """

    func formattedText() -> NSAttributedString {
        let basicFont = NSFont.systemFont(ofSize: 12)
        let basicAttributes = [NSAttributedString.Key.font: basicFont, .foregroundColor: defaultTextColor]
        let supportText = NSMutableAttributedString(string: supportText, attributes: basicAttributes)
        
        let tdRange  = supportText.mutableString.range(of: "https://telemetrydeck.com")
        if tdRange.location != NSNotFound {
            supportText.addAttribute(NSAttributedString.Key.link, value: "https://telemetrydeck.com", range: tdRange)
        }
        
        let aboutString = supportText
        
        let currentYear = "\(Calendar.current.component(.year, from: Date()))"
        
        let feedbackString = NSMutableAttributedString(string: feedback, attributes: basicAttributes)
        
        let issuesRange  = feedbackString.mutableString.range(of: "filing an issue")
        if issuesRange.location != NSNotFound {
            feedbackString.addAttribute(NSAttributedString.Key.link, value: "https://github.com/Jamf-Concepts/wallpaper-designer/issues", range: issuesRange)
        }
        aboutString.append(feedbackString)
        
        let warningFont = NSFont(name: "HelveticaNeue-Italic", size: 12)
    //        let warningFont = NSFont.systemFont(ofSize: 12)
        let warningAttributes = [NSAttributedString.Key.font: warningFont, .foregroundColor: defaultTextColor]
        let warningString = NSMutableAttributedString(string: warningText, attributes: warningAttributes as [NSAttributedString.Key : Any])
        aboutString.append(warningString)
        
        let agreementString = NSMutableAttributedString(string: agreementText.replacingOccurrences(of: "Copyright xxxx", with: "Copyright \(currentYear)"), attributes: basicAttributes)
        let foundRange        = agreementString.mutableString.range(of: "Jamf Concepts Use Agreement")
        if foundRange.location != NSNotFound {
            agreementString.addAttribute(NSAttributedString.Key.link, value: "https://resources.jamf.com/documents/jamf-concept-projects-use-agreement.pdf", range: foundRange)
        }
        aboutString.append(agreementString)
        
        return aboutString
    }
    
    @IBOutlet weak var about_image: NSImageView!
    
    @IBOutlet weak var appName_textfield: NSTextField!
    @IBOutlet weak var version_textfield: NSTextField!
    @IBOutlet var license_textfield: NSTextView!
    
    @objc func interfaceModeChanged(sender: NSNotification) {
        license_textfield.textStorage?.setAttributedString(formattedText())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(interfaceModeChanged(sender:)), name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil)
        
        view.window?.titlebarAppearsTransparent = true
        view.window?.isOpaque = false
        
        about_image.image = NSImage(named: "AppIcon")
                
        appName_textfield.stringValue = AppInfo.name
        version_textfield.stringValue = "Version \(AppInfo.version) (\(AppInfo.build))"
        license_textfield.textStorage?.setAttributedString(formattedText())
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        DistributedNotificationCenter.default.removeObserver("AppleInterfaceThemeChangedNotification")
    }
    
    func grayscale(image: CGImage, theSize: NSSize) -> NSImage? {
        let context = CIContext(options: nil)
        
        if let filter = CIFilter(name: "CIPhotoEffectTonal") {
                        
            filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)

            if let output = filter.outputImage {
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    return NSImage(cgImage: cgImage, size: theSize)
                }
            }
        }
        return nil
    }
}

extension NSImage {
   func newCIImage() -> CIImage? {
      if let cgImage = self.newCGImage() {
         return CIImage(cgImage: cgImage)
      }
      return nil
   }

   func newCGImage() -> CGImage? {
      var imageRect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.size)
      return self.cgImage(forProposedRect: &imageRect, context: NSGraphicsContext.current, hints: nil)
    }
}

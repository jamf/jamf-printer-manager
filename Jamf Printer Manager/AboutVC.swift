//
//  Copyright 2024, Jamf
//

import AppKit
import Cocoa
import Foundation

class AboutVC: NSViewController {
    
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

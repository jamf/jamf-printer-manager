//
//  Copyright 2023 jamf. All rights reserved.
//


import Cocoa
import Foundation


class PrinterInfoVC: NSTabViewController, NSWindowDelegate {
    
    var editPrinterInfo = PrinterInfo(id: "", name: "", category: "", uri: "", cups_name: "", location: "", model: "", make_default: "", shared: "", info: "", notes: "", use_generic: "", ppd: "", ppd_contents: "", ppd_path: "", os_req: "")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        let theWidth  = 768
        let theHeight = 480
        var frame = self.view.window!.frame
        let initialSize = NSSize(width: theWidth, height: theHeight)
        self.view.window?.minSize = NSSize(width: theWidth, height: theHeight)
        self.view.window?.maxSize = NSSize(width: 1440, height: theHeight)
        frame.size = initialSize
        self.view.window?.setFrame(frame, display: true)
    }
    
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        EditPrinter.viewDidAppear        = false
        EditPrinter.generalDidAppear     = false
        EditPrinter.definitionDidAppear  = false
        EditPrinter.limitationsDidAppear = false
    }
}

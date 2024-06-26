//
//  Copyright 2024, Jamf
//

import Cocoa
import WebKit

class HelpVC: NSViewController {
    
    @IBOutlet weak var help_WebView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let   filePath = Bundle.main.path(forResource: "jpm_help", ofType: "html")
        let folderPath = Bundle.main.resourcePath
        
        let fileUrl = URL(fileURLWithPath: filePath!)
        let baseUrl = URL(fileURLWithPath: folderPath!, isDirectory: true)
        
        help_WebView.loadFileURL(fileUrl as URL, allowingReadAccessTo: baseUrl as URL)
    }
    
}

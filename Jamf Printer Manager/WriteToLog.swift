//
//  Copyright 2024, Jamf
//

import Foundation
class WriteToLog {
    
    static let shared = WriteToLog()
    private init() { }
    
    func message(stringOfText: String) {

         let logString = "\(getCurrentTime()) \(stringOfText)\n"

         Log.file_FH = FileHandle(forUpdatingAtPath: (Log.path! + Log.file))
         
         let historyText = (logString as NSString).data(using: String.Encoding.utf8.rawValue)
         Log.file_FH?.seekToEndOfFile()
         Log.file_FH?.write(historyText!)
     }
}

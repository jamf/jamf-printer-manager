//
//  Copyright 2026, Jamf
//

import Foundation

struct Log {
    static var path     = ""
    static var file     = "JamfPrinterManager.log"
    static var filePath = ""
    static var maxFiles = 42
}

final class WriteToLog {
    
    static let shared = WriteToLog()
    private init() { }
    
    func message(_ message: String) {
        let logString = "\(getCurrentTime()) \(message)\n"
        NSLog(logString)

        guard let logData = logString.data(using: .utf8) else { return }
        let logURL = URL(fileURLWithPath: Log.filePath)

        do {
            let fileHandle = try FileHandle(forWritingTo: logURL)
            defer { fileHandle.closeFile() } // Ensure file is closed
            
            fileHandle.seekToEndOfFile()
            fileHandle.write(logData)
        } catch {
            NSLog("[Log Error] Failed to write to log file: \(error.localizedDescription)")
        }
    }
}

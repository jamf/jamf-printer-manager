//
//  Copyright 2023 jamf. All rights reserved.
//

import Foundation

// func cleanup - start
func cleanup() {
    let maxLogFileCount = 42 //(defaults.integer(forKey: "logFilesCountPref") < 1) ? 20:defaults.integer(forKey: "logFilesCountPref")
    var logArray: [String] = []
    var logCount: Int = 0
    do {
        let logFiles = try FileManager.default.contentsOfDirectory(atPath: Log.path!)
        
        for logFile in logFiles {
            let filePath: String = Log.path! + logFile //Log.file
//            print("filePath: \(filePath)")
            logArray.append(filePath)
        }
        logArray.sort()
        logCount = logArray.count
        if didRun {
            // remove old history files
            if logCount > maxLogFileCount {
                for i in (0..<logCount-maxLogFileCount) {
//                    if LogLevel.debug { WriteToLog.shared.message(stringOfText: "Deleting log file: " + logArray[i] + "\n") }
                    
                    do {
                        try FileManager.default.removeItem(atPath: logArray[i])
                    }
                    catch let error as NSError {
                        WriteToLog.shared.message(stringOfText: "Error deleting log file:\n    " + logArray[i] + "\n    \(error)")
                    }
                }
            }
        } else {
            // delete empty log file
            if logCount > 0 {
                
            }
            do {
                try FileManager.default.removeItem(atPath: logArray[0])
            }
            catch let error as NSError {
                WriteToLog.shared.message(stringOfText: "Error deleting log file:    \n" + Log.path! + logArray[0] + "    \(error)")
            }
        }
    } catch {
        WriteToLog.shared.message(stringOfText: "no log files found")
    }
}

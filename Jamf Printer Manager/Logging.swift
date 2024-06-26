//
//  Copyright 2024, Jamf
//

import Foundation

func cleanup() {
    let maxLogFileCount = 42
    var logArray: [String] = []
    var logCount: Int = 0
    do {
        let logFiles = try FileManager.default.contentsOfDirectory(atPath: Log.path!)
        
        for logFile in logFiles {
            let filePath: String = Log.path! + logFile
            logArray.append(filePath)
        }
        logArray.sort()
        logCount = logArray.count
        if didRun {
            if logCount > maxLogFileCount {
                for i in (0..<logCount-maxLogFileCount) {
                    
                    do {
                        try FileManager.default.removeItem(atPath: logArray[i])
                    }
                    catch let error as NSError {
                        WriteToLog.shared.message(stringOfText: "Error deleting log file:\n    " + logArray[i] + "\n    \(error)")
                    }
                }
            }
        } else {
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

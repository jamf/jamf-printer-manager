//
//  Copyright 2026, Jamf
//

import Foundation

func cleanup() {
    guard didRun else {
        // Delete empty log file
        do {
            try FileManager.default.removeItem(atPath: Log.filePath)
        } catch {
            WriteToLog.shared.message("Error deleting log file: \(Log.filePath)\n    \(error)\n")
        }
        return
    }
    
    do {
        let logFiles = try FileManager.default.contentsOfDirectory(atPath: Log.path)
            .map { "\(Log.path)/\($0)" }
            .sorted()
        
        let filesToDelete = logFiles.dropLast(Log.maxFiles)
        
        for filePath in filesToDelete {
            WriteToLog.shared.message("Deleting log file: \(filePath)\n")
            do {
                try FileManager.default.removeItem(atPath: filePath)
            } catch {
                WriteToLog.shared.message("Error deleting log file: \(filePath)\n    \(error)\n")
            }
        }
    } catch {
        NSLog("No history")
    }
}

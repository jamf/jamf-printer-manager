//
//  Copyright 2026, Jamf
//

import Cocoa

class FolderBookmark {

    static let shared = FolderBookmark()
    private init() {}

    private let key = "outputFolderBookmarks"

    func save(folderURL: URL) {
        do {
            let data = try folderURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var stored = userDefaults.array(forKey: key) as? [Data] ?? []
            // Replace any existing bookmark for this path
            stored.removeAll { existing in
                var stale = false
                if let url = try? URL(resolvingBookmarkData: existing,
                                      options: [.withoutUI, .withSecurityScope],
                                      bookmarkDataIsStale: &stale) {
                    return url.path == folderURL.path
                }
                return false
            }
            stored.append(data)
            userDefaults.set(stored, forKey: key)
        } catch {
            WriteToLog.shared.message("[FolderBookmark] save failed: \(error.localizedDescription)")
        }
    }

    // Returns the resolved, security-scoped folder URL with access already started,
    // or nil if no matching bookmark exists.
    func startAccessing(folderURL: URL) -> URL? {
        // Downloads is always accessible in the sandbox — no bookmark needed
        let home      = FileManager.default.homeDirectoryForCurrentUser
        let downloads = home.appendingPathComponent("Downloads").path
        if folderURL.path.hasPrefix(downloads) { return folderURL }

        let stored = userDefaults.array(forKey: key) as? [Data] ?? []
        for data in stored {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data,
                                     options: [.withSecurityScope],
                                     bookmarkDataIsStale: &isStale),
                  !isStale,
                  folderURL.path.hasPrefix(url.path) else { continue }

            if url.startAccessingSecurityScopedResource() { return url }
        }
        WriteToLog.shared.message("[FolderBookmark] no matching bookmark for: \(folderURL.path)")
        return nil
    }

    func stopAccessing(_ scopedURL: URL) {
        scopedURL.stopAccessingSecurityScopedResource()
    }
}

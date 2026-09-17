//
//  JamfSchoolPrinterSettingsVC.swift
//

import Cocoa
import Foundation

class JamfSchoolPrinterSettingsVC: NSViewController {

    var printerDisplayName = ""
    var selectedPrinter: PrinterInfo?
    private var outputFolderBookmark: Data?

    @IBOutlet weak var displayName_TextField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        displayName_TextField.stringValue = printerDisplayName
        requireAdmin_Button.isEnabled = allowLocal_Button.state == .on
    }

    @IBAction func allowLocal_Action(_ sender: NSButton) {
        requireAdmin_Button.isEnabled = sender.state == .on
        if sender.state == .off {
            requireAdmin_Button.state = .off
        }
    }
    
    @IBOutlet weak var modify_Button: NSButton!
    @IBOutlet weak var allowLocal_Button: NSButton!
    @IBOutlet weak var requireAdmin_Button: NSButton!
    @IBOutlet weak var showManaged_Button: NSButton!
    @IBOutlet weak var setDefault_Button: NSButton!
    @IBOutlet weak var footer_Button: NSButton!
    
    @IBOutlet weak var cancel_Button: NSButton!
    @IBOutlet weak var create_Button: NSButton!
    
    @IBAction func cancel_Action(_ sender: Any) {
        dismiss(self)
    }
    
    @IBAction func create_Action(_ sender: Any) {
        guard let printer = selectedPrinter else { return }

        let profileName = displayName_TextField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !profileName.isEmpty else { return }

        let outerUUID = UUID().uuidString
        let innerUUID = UUID().uuidString
        let org       = JamfProServer.displayName

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let createdStamp = dateFormatter.string(from: Date())

        func boolTag(_ v: Bool) -> String { v ? "<true/>" : "<false/>" }

        let allowLocal        = allowLocal_Button.state    == .on
        let requireAdminAdd   = modify_Button.state        == .on
        let requireAdminPrint = requireAdmin_Button.state  == .on
        let showManaged       = showManaged_Button.state   == .on
        let makeDefault       = setDefault_Button.state    == .on
        let printFooter       = footer_Button.state        == .on

        let ppdURL = "file://localhost\(printer.ppd_path)"

        let defaultPrinterXML = makeDefault
            ? "<key>DefaultPrinter</key>\n<dict>\n<key>DeviceURI</key><string>\(printer.uri)</string>\n<key>DisplayName</key><string>\(profileName)</string>\n</dict>"
            : "<key>DefaultPrinter</key><string/>"

        let profileXML = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1">
<dict>
<key>PayloadUUID</key><string>\(outerUUID)</string>
<key>PayloadType</key><string>Configuration</string>
<key>PayloadOrganization</key><string>\(org)</string>
<key>PayloadIdentifier</key><string>\(outerUUID)</string>
<key>PayloadDisplayName</key><string>\(profileName)</string>
<key>PayloadDescription</key><string>Printer profile for model \(printer.model). Created with Jamf Printer Manager: \(createdStamp)</string>
<key>PayloadVersion</key><integer>1</integer>
<key>PayloadEnabled</key><true/>
<key>PayloadRemovalDisallowed</key><true/>
<key>PayloadScope</key><string>System</string>
<key>PayloadContent</key>
<array>
<dict>
<key>PayloadUUID</key><string>\(innerUUID)</string>
<key>PayloadType</key><string>com.apple.mcxprinting</string>
<key>PayloadOrganization</key><string>\(org)</string>
<key>PayloadIdentifier</key><string>\(innerUUID)</string>
<key>PayloadDisplayName</key><string>Printing</string>
<key>PayloadDescription</key><string/>
<key>PayloadVersion</key><integer>1</integer>
<key>PayloadEnabled</key><true/>
<key>AllowLocalPrinters</key>\(boolTag(allowLocal))
<key>FooterFontName</key><string>Helvetica</string>
<key>FooterFontSize</key><string>7</string>
<key>PrintFooter</key>\(boolTag(printFooter))
<key>PrintMACAddress</key><false/>
<key>RequireAdminToAddPrinters</key>\(boolTag(requireAdminAdd))
<key>RequireAdminToPrintLocally</key>\(boolTag(requireAdminPrint))
<key>ShowOnlyManagedPrinters</key>\(boolTag(showManaged))
<key>UserPrinterList</key>
<dict>
<key>\(profileName)</key>
<dict>
<key>PPDURL</key><string>\(ppdURL)</string>
<key>PrinterLocked</key><false/>
<key>DeviceURI</key><string>\(printer.uri)</string>
<key>DisplayName</key><string>\(profileName)</string>
<key>Model</key><string>\(printer.model)</string>
<key>Location</key><string>\(printer.location)</string>
</dict>
</dict>
\(defaultPrinterXML)
</dict>
</array>
</dict>
</plist>
"""
        saveFiles(name: profileName, xmlData: profileXML, printer: printer)
    }

    private func saveFiles(name: String, xmlData: String, printer: PrinterInfo) {
        guard !printer.ppd_contents.isEmpty else {
            _ = Alert.shared.display(header: "No PPD Available:",
                                     message: "There is no PPD file associated with this printer. A package cannot be created.",
                                     secondButton: "")
            return
        }

        guard let profileData = xmlData.data(using: .utf8) else { return }

        let panel = NSOpenPanel()
        panel.message                 = "Choose a folder — the profile and package will be saved here"
        panel.prompt                  = "Save Here"
        panel.canChooseFiles          = false
        panel.canChooseDirectories    = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories    = true

        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self, response == .OK, let folderURL = panel.url else { return }

            // Capture folder-level bookmark while access is live.
            self.outputFolderBookmark = try? folderURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            FolderBookmark.shared.save(folderURL: folderURL)

            let safeName    = name
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }

            func uniqueURL(in folder: URL, base: String, ext: String) -> URL {
                var candidate = folder.appendingPathComponent("\(base).\(ext)")
                var counter   = 2
                while FileManager.default.fileExists(atPath: candidate.path) {
                    candidate = folder.appendingPathComponent("\(base)_\(counter).\(ext)")
                    counter  += 1
                }
                return candidate
            }

            let profileURL = uniqueURL(in: folderURL, base: safeName,          ext: "mobileconfig")
            let pkgURL     = uniqueURL(in: folderURL, base: "\(safeName)_PPD", ext: "pkg")
            do {
                try profileData.write(to: profileURL)
            } catch {
                WriteToLog.shared.message("[JamfSchoolPrinterSettingsVC] profile save failed: \(error.localizedDescription)")
                _ = Alert.shared.display(header: "Error:", message: "Could not save profile: \(error.localizedDescription)", secondButton: "")
                return
            }
            let ppdFilename = URL(fileURLWithPath: printer.ppd_path).lastPathComponent
            self.createPkg(ppdContents: printer.ppd_contents.xmlDecode,
                           ppdFilename: ppdFilename,
                           outputURL: pkgURL)
        }
    }

    private func createPkg(ppdContents: String, ppdFilename: String, outputURL: URL) {
        let tempRoot   = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tempPPDDir = tempRoot.appendingPathComponent("private/etc/cups/ppd")

        do {
            try FileManager.default.createDirectory(at: tempPPDDir, withIntermediateDirectories: true)
            try ppdContents.write(to: tempPPDDir.appendingPathComponent(ppdFilename),
                                  atomically: true, encoding: .utf8)
        } catch {
            WriteToLog.shared.message("[JamfSchoolPrinterSettingsVC] pkg staging failed: \(error.localizedDescription)")
            _ = Alert.shared.display(header: "Error:", message: "Could not prepare package contents: \(error.localizedDescription)", secondButton: "")
            return
        }

        // pkgbuild writes to a temp path — child processes don't inherit security-scoped
        // permissions granted by NSSavePanel, so writing directly to outputURL would fail.
        // FileManager.moveItem below does have that access.
        let tempOutput = FileManager.default.temporaryDirectory.appendingPathComponent(outputURL.lastPathComponent)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/productbuild")
        process.arguments = [
            "--identifier", "com.jamf.printer.\(ppdFilename.replacingOccurrences(of: ".ppd", with: ""))",
            "--version",    "1.0",
            "--root",       tempRoot.path,
            "/",
            tempOutput.path
        ]
        let errorPipe = Pipe()
        process.standardError = errorPipe

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    try? FileManager.default.removeItem(at: tempRoot)
                    WriteToLog.shared.message("[JamfSchoolPrinterSettingsVC] pkgbuild launch failed: \(error.localizedDescription)")
                    _ = Alert.shared.display(header: "Error:", message: "Could not run pkgbuild: \(error.localizedDescription)", secondButton: "")
                }
                return
            }

            let status    = process.terminationStatus
            let errOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            try? FileManager.default.removeItem(at: tempRoot)

            DispatchQueue.main.async {
                guard status == 0 else {
                    try? FileManager.default.removeItem(at: tempOutput)
                    WriteToLog.shared.message("[JamfSchoolPrinterSettingsVC] pkgbuild exited \(status): \(errOutput)")
                    _ = Alert.shared.display(header: "Error:", message: "Package creation failed:\n\(errOutput)", secondButton: "")
                    return
                }
                var scopedURL: URL?
                if let data = self?.outputFolderBookmark {
                    var isStale = false
                    scopedURL = try? URL(resolvingBookmarkData: data,
                                        options: [.withSecurityScope],
                                        bookmarkDataIsStale: &isStale)
                    _ = scopedURL?.startAccessingSecurityScopedResource()
                }
                defer { scopedURL?.stopAccessingSecurityScopedResource() }
                do {
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        try FileManager.default.removeItem(at: outputURL)
                    }
                    try FileManager.default.moveItem(at: tempOutput, to: outputURL)
                    TelemetryDeckSignal.shared.send("printerCreated",
                        parameters: ["clientType": "Jamf School"])
                    self?.dismiss(self!)
                } catch {
                    WriteToLog.shared.message("[JamfSchoolPrinterSettingsVC] pkg move failed: \(error.localizedDescription)")
                    _ = Alert.shared.display(header: "Error:", message: "Could not move package to destination: \(error.localizedDescription)", secondButton: "")
                }
            }
        }
    }
    
}

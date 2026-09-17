//
//  Copyright 2026, Jamf
//

import Cocoa
import Foundation

class GetPrintersDelegate: NSObject, URLSessionDelegate {

    static let shared = GetPrintersDelegate()
    private override init() { }

    var endpointPath = ""

    // MARK: - Jamf School: fetch profiles and filter for printer-related entries

    func schoolPrinterProfiles(completion: @escaping (_ printers: [PrinterInfo]) -> Void) {
        let baseURL = JamfProServer.destination.hasSuffix("/")
            ? String(JamfProServer.destination.dropLast())
            : JamfProServer.destination

        func makeRequest(_ path: String) -> URLRequest? {
            guard let url = URL(string: "\(baseURL)\(path)") else { return nil }
            var req = URLRequest(url: url)
            req.setValue("\(JamfProServer.authType) \(JamfProServer.accessToken)",
                         forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("4",               forHTTPHeaderField: "X-Server-Protocol-Version")
            return req
        }

        guard let listRequest = makeRequest("/api/profiles/") else { completion([]); return }
        WriteToLog.shared.message("[GetPrintersDelegate.schoolPrinterProfiles] fetching \(baseURL)/api/profiles/")

        URLSession.shared.dataTask(with: listRequest) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 || status == 403 {
                WriteToLog.shared.message("[GetPrintersDelegate.schoolPrinterProfiles] HTTP \(status): authentication failed")
                DispatchQueue.main.async {
                    _ = Alert.shared.display(header: "Authentication Failed:",
                                             message: "Unable to authenticate to Jamf School.\nPlease check your Network ID and API Key.",
                                             secondButton: "")
                    completion([])
                    NotificationCenter.default.post(name: .returnToLoginNotification, object: nil)
                }
                return
            }
            guard let data     = data,
                  let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let profiles = json["profiles"] as? [[String: Any]] else {
                WriteToLog.shared.message("[GetPrintersDelegate.schoolPrinterProfiles] HTTP \(status), failed to parse profile list: \(String(data: data ?? Data(), encoding: .utf8) ?? "")")
                DispatchQueue.main.async { completion([]) }
                return
            }

            let matched = profiles.filter {
                let name = ($0["name"]        as? String ?? "").lowercased()
                let desc = ($0["description"] as? String ?? "").lowercased()
                return name.contains("print") || desc.contains("print")
            }
            WriteToLog.shared.message("[GetPrintersDelegate.schoolPrinterProfiles] HTTP \(status): \(matched.count) printer profile(s) out of \(profiles.count)")

            guard !matched.isEmpty else { DispatchQueue.main.async { completion([]) }; return }

            var results = [PrinterInfo]()
            let group   = DispatchGroup()
            let lock    = NSLock()

            for profile in matched {
                guard let id = profile["id"] as? Int,
                      let req = makeRequest("/api/profiles/\(id)") else { continue }
                group.enter()
                URLSession.shared.dataTask(with: req) { data, _, _ in
                    defer { group.leave() }
                    guard let data   = data,
                          let detail = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                    let info = PrinterInfo(
                        id:           "\(id)",
                        name:         detail["name"]        as? String ?? "",
                        category:     "",
                        uri:          "",
                        cups_name:    "",
                        location:     "",
                        model:        "",
                        make_default: "false",
                        shared:       "false",
                        info:         detail["description"] as? String ?? "",
                        notes:        "",
                        use_generic:  "false",
                        ppd:          "",
                        ppd_contents: "",
                        ppd_path:     "",
                        os_req:       ""
                    )
                    lock.lock(); results.append(info); lock.unlock()
                }.resume()
            }
            group.notify(queue: .main) { completion(results) }
        }.resume()
    }

    // MARK: - apiAction

    func apiAction(method: String, theEndpoint: String, acceptFormat: String = "application/json", completion: @escaping (_ result: (Int,Data)) -> Void) {

        guard theEndpoint.prefix(4) != "skip" else {
            completion((200, Data()))
            return
        }

        let getRecordQ = OperationQueue()
        URLCache.shared.removeAllCachedResponses()

        var existingDestUrl: String
        if useApiClient == 0 {
            existingDestUrl = "https://\(JamfProServer.region).api.jamfcloud.com/proclassic/\(theEndpoint)"
        } else {
            existingDestUrl = "\(JamfProServer.destination)/JSSResource/\(theEndpoint)"
            existingDestUrl = existingDestUrl.urlFix
        }

        WriteToLog.shared.message("[GetPrintersDelegate.apiAction] Looking up: \(existingDestUrl)")

        guard let destEncodedURL = URL(string: existingDestUrl) else {
            WriteToLog.shared.message("[GetPrintersDelegate.apiAction] invalid URL: \(existingDestUrl)")
            completion((500, Data()))
            return
        }
        let jsonRequest = NSMutableURLRequest(url: destEncodedURL)

        let semaphore = DispatchSemaphore(value: 1)
        getRecordQ.maxConcurrentOperationCount = 3
        getRecordQ.addOperation {

            let tokenServerUrl = useApiClient == 0 ? JamfProServer.tenantId : JamfProServer.destination
            TokenDelegate.shared.getToken(serverUrl: tokenServerUrl, base64creds: JamfProServer.base64Creds) { [self]
                authResult in
                let (statusCode, theResult) = authResult
                if theResult == "success" {

                    jsonRequest.httpMethod = "\(method.uppercased())"
                    let destConf = URLSessionConfiguration.default

                    if useApiClient == 0 {
                        destConf.httpAdditionalHeaders = [
                            "Authorization": "Bearer \(JamfProServer.accessToken)",
                            "Accept":        acceptFormat,
                            "User-Agent":    AppInfo.userAgentHeader,
                            "X-Tenant-Id":   JamfProServer.tenantId
                        ]
                    } else {
                        destConf.httpAdditionalHeaders = [
                            "Authorization": "\(JamfProServer.authType) \(JamfProServer.accessToken)",
                            "Accept":        acceptFormat,
                            "User-Agent":    AppInfo.userAgentHeader
                        ]
                        if JamfProServer.sessionCookie.count > 0 && JamfProServer.stickySession {
                            URLSession.shared.configuration.httpCookieStorage!.setCookies(
                                JamfProServer.sessionCookie,
                                for: URL(string: JamfProServer.destination),
                                mainDocumentURL: URL(string: JamfProServer.destination)
                            )
                        }
                    }

                    let startDate   = Date()
                    let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
                    let task = destSession.dataTask(with: jsonRequest as URLRequest, completionHandler: {
                        (data, response, error) -> Void in
                        destSession.finishTasksAndInvalidate()
                        let (_, _, _, tokenAgeInSeconds) = timeDiff(startTime: startDate)
                        WriteToLog.shared.message("[GetPrintersDelegate.apiAction] query time for \(method) on \(existingDestUrl): \(tokenAgeInSeconds) seconds")

                        if let httpResponse = response as? HTTPURLResponse {
                            if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299, let myData = data {
                                completion((httpResponse.statusCode, myData))
                            } else {
                                WriteToLog.shared.message("[GetPrintersDelegate.apiAction] \(existingDestUrl) lookup encountered an error.  HTTP Status Code: \(httpResponse.statusCode)")
                                WriteToLog.shared.message("[GetPrintersDelegate.apiAction] reply: \(String(describing: String(data: data ?? Data(), encoding: .utf8)))")
                                completion((httpResponse.statusCode, Data()))
                            }
                        } else {
                            WriteToLog.shared.message("[GetPrintersDelegate.apiAction] error getting JSON for \(existingDestUrl)")
                            completion((0, Data()))
                        }
                        semaphore.signal()
                    })
                    task.resume()

                } else {
                    WriteToLog.shared.message("Failed to authenticate to \(existingDestUrl), status code: \(statusCode)")
                    completion((statusCode, Data()))
                }
            }
        }
    }
}

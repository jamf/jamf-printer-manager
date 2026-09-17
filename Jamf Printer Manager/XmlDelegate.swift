//
//  Copyright 2026, Jamf
//

import Cocoa
import Foundation

class XmlDelegate: NSObject, URLSessionDelegate {

    static let shared = XmlDelegate()
    private override init() { }

    var baseXmlFolder = ""
    var saveXmlFolder = ""
    var endpointPath  = ""

    // MARK: - apiAction

    func apiAction(method: String, theEndpoint: String, xmlData: String = "", acceptFormat: String = "text/xml", completion: @escaping (_ result: (Int,Any)) -> Void) {

        guard theEndpoint.prefix(4) != "skip" else {
            completion((200,""))
            return
        }

        let getRecordQ = OperationQueue()
        URLCache.shared.removeAllCachedResponses()

        if useApiClient == 0 {
            // Platform API: route Classic endpoints through the proclassic gateway
            let destUrl = "https://\(JamfProServer.region).api.jamfcloud.com/proclassic/\(theEndpoint)"
            WriteToLog.shared.message("[XmlDelegate.apiAction] Platform lookup: \(destUrl)")

            getRecordQ.addOperation {
                TokenDelegate.shared.getToken(serverUrl: JamfProServer.tenantId, base64creds: "") { [self] authResult in
                    let (statusCode, theResult) = authResult
                    guard theResult == "success" else {
                        WriteToLog.shared.message("[XmlDelegate.apiAction] Platform auth failed: \(statusCode)")
                        completion((statusCode, ""))
                        return
                    }

                    guard let url = URL(string: destUrl) else { completion((500, "")); return }
                    let xmlRequest = NSMutableURLRequest(url: url)
                    xmlRequest.httpMethod = method.uppercased()

                    if method.uppercased() == "POST" || method.uppercased() == "PUT" {
                        xmlRequest.httpBody = xmlData.data(using: .utf8)
                    }

                    let conf = URLSessionConfiguration.default
                    conf.httpAdditionalHeaders = [
                        "Authorization": "Bearer \(JamfProServer.accessToken)",
                        "Content-Type":  "text/xml",
                        "Accept":        acceptFormat,
                        "User-Agent":    AppInfo.userAgentHeader,
                        "X-Tenant-Id":   JamfProServer.tenantId
                    ]

                    let session = Foundation.URLSession(configuration: conf, delegate: self, delegateQueue: OperationQueue.main)
                    let task = session.dataTask(with: xmlRequest as URLRequest) { data, response, _ in
                        session.finishTasksAndInvalidate()
                        guard let httpResponse = response as? HTTPURLResponse else {
                            completion((0, ""))
                            return
                        }
                        guard httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 else {
                            WriteToLog.shared.message("[XmlDelegate.apiAction] Platform error \(httpResponse.statusCode) for \(destUrl)")
                            if let d = data { WriteToLog.shared.message("[XmlDelegate.apiAction] reply: \(String(data: d, encoding: .utf8) ?? "")") }
                            completion((httpResponse.statusCode, ""))
                            return
                        }
                        guard let data = data else { completion((httpResponse.statusCode, "")); return }

                        if acceptFormat == "text/xml" {
                            let returnedXML = String(data: data, encoding: .utf8) as Any
                            completion((httpResponse.statusCode, returnedXML))
                        } else {
                            let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
                            completion((httpResponse.statusCode, json as Any))
                        }
                    }
                    task.resume()
                }
            }

        } else {
            // Classic API path (existing behaviour)
            var existingDestUrl = "\(JamfProServer.destination)/JSSResource/\(theEndpoint)"
            existingDestUrl = existingDestUrl.urlFix

            if method == "GET" && xmlData != "" {
                WriteToLog.shared.message("[XmlDelegate.apiAction] Looking up: \(xmlData), id: \(URL(string: existingDestUrl)!.lastPathComponent)")
            } else {
                WriteToLog.shared.message("[XmlDelegate.apiAction] Looking up: \(existingDestUrl)")
            }

            let destEncodedURL = URL(string: existingDestUrl)
            let xmlRequest     = NSMutableURLRequest(url: destEncodedURL! as URL)

            let semaphore = DispatchSemaphore(value: 1)
            getRecordQ.maxConcurrentOperationCount = 3
            getRecordQ.addOperation {

                TokenDelegate.shared.getToken(serverUrl: JamfProServer.destination, base64creds: JamfProServer.base64Creds) { [self]
                    authResult in
                    let (statusCode,theResult) = authResult
                    if theResult == "success" {

                        xmlRequest.httpMethod = "\(method.uppercased())"
                        let destConf = URLSessionConfiguration.default

                        if method.uppercased() == "POST" || method.uppercased() == "PUT" {
                            let encodedXML = xmlData.data(using: String.Encoding.utf8)
                            xmlRequest.httpBody = encodedXML!
                        }

                        destConf.httpAdditionalHeaders = ["Authorization" : "\(String(describing: JamfProServer.authType)) \(String(describing: JamfProServer.accessToken))", "Content-Type" : "text/xml", "Accept" : acceptFormat, "User-Agent" : AppInfo.userAgentHeader]

                        if JamfProServer.sessionCookie.count > 0 && JamfProServer.stickySession {
                            URLSession.shared.configuration.httpCookieStorage!.setCookies(JamfProServer.sessionCookie, for: URL(string: JamfProServer.destination), mainDocumentURL: URL(string: JamfProServer.destination))
                        }
                        let startDate   = Date()
                        let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
                        let task = destSession.dataTask(with: xmlRequest as URLRequest, completionHandler: {
                            (data, response, error) -> Void in
                            destSession.finishTasksAndInvalidate()
                            let (_, _, _, tokenAgeInSeconds) = timeDiff(startTime: startDate)
                            WriteToLog.shared.message("[XmlDelegate.apiAction] query time for \(method) on \(existingDestUrl): \(tokenAgeInSeconds) seconds")

                            if let httpResponse = response as? HTTPURLResponse {
                                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                                    if acceptFormat == "text/xml" {
                                        let returnedXML = String(data: data!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))! as Any
                                        completion((httpResponse.statusCode,returnedXML))
                                    } else {
                                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                                        completion((httpResponse.statusCode,json as Any))
                                    }
                                } else {
                                    WriteToLog.shared.message("[XmlDelegate.apiAction] \(existingDestUrl) lookup encountered an error.  HTTP Status Code: \(httpResponse.statusCode)")
                                    WriteToLog.shared.message("[XmlDelegate.apiAction] reply: \(String(describing: String(data: data!, encoding: .utf8)))")
                                    WriteToLog.shared.message("[XmlDelegate.apiAction] uploaded xml: \(xmlData)")
                                    completion((httpResponse.statusCode,""))
                                }
                            } else {
                                WriteToLog.shared.message("[XmlDelegate.apiAction] error getting XML for \(existingDestUrl)")
                                completion((0,""))
                            }
                            semaphore.signal()
                        })
                        task.resume()

                    } else {
                        WriteToLog.shared.message("Failed to authenticate to \(existingDestUrl), status code: \(statusCode)")
                        completion((statusCode,""))
                    }
                }
            }
        }
    }
}

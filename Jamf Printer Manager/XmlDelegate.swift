//
//  Copyright 2023 jamf. All rights reserved.
//

import Cocoa
import Foundation

class XmlDelegate: NSObject, URLSessionDelegate {
    
    static let shared = XmlDelegate()
    private override init() { }

    var baseXmlFolder = ""
    var saveXmlFolder = ""
    var endpointPath  = ""
//    let backupDate    = DateFormatter()

    func apiAction(method: String, theEndpoint: String, xmlData: String = "", acceptFormat: String = "text/xml", completion: @escaping (_ result: (Int,Any)) -> Void) {
        
        if theEndpoint.prefix(4) != "skip" {
            let getRecordQ = OperationQueue()   //DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)
        
            URLCache.shared.removeAllCachedResponses()
            var existingDestUrl = ""
            
            existingDestUrl = "\(JamfProServer.destination)/JSSResource/\(theEndpoint)"
            existingDestUrl = existingDestUrl.urlFix
//            print("existingDestUrl: \(existingDestUrl)")
//            existingDestUrl = existingDestUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
            if method == "GET" && xmlData != "" {
                WriteToLog.shared.message(stringOfText: "[XmlDelegate.apiAction] Looking up: \(xmlData), id: \(URL(string: existingDestUrl)!.lastPathComponent)")
            } else {
                WriteToLog.shared.message(stringOfText: "[XmlDelegate.apiAction] Looking up: \(existingDestUrl)")
            }
//                    if "\(existingDestUrl)" == "" { existingDestUrl = "https://localhost" }
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
                            // add data to request body
        //                    print("[apiAction] xmlData:\n\(xmlData)")
                            let encodedXML = xmlData.data(using: String.Encoding.utf8)
                            xmlRequest.httpBody = encodedXML!
                        }

                        destConf.httpAdditionalHeaders = ["Authorization" : "\(String(describing: JamfProServer.authType)) \(String(describing: JamfProServer.accessToken))", "Content-Type" : "text/xml", "Accept" : acceptFormat, "User-Agent" : AppInfo.userAgentHeader]
//                        WriteToLog.shared.message(stringOfText: "[XmlDelegate.apiAction] destConf.httpAdditionalHeaders: \(String(describing: destConf.httpAdditionalHeaders))")
                        
                        // sticky session
                        if JamfProServer.sessionCookie.count > 0 && JamfProServer.stickySession {
        //                    print("xml sticky session for \(JamfProServer.destination)")
                            URLSession.shared.configuration.httpCookieStorage!.setCookies(JamfProServer.sessionCookie, for: URL(string: JamfProServer.destination), mainDocumentURL: URL(string: JamfProServer.destination))
                        }
                        let startDate = Date()
                        let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
                        let task = destSession.dataTask(with: xmlRequest as URLRequest, completionHandler: {
                            (data, response, error) -> Void in
                            destSession.finishTasksAndInvalidate()
                            let (_, _, _, tokenAgeInSeconds) = timeDiff(startTime: startDate)
                            WriteToLog.shared.message(stringOfText: "[XmlDelegate.apiAction] query time for \(method) on \(existingDestUrl): \(tokenAgeInSeconds) seconds")
                            
                            if let httpResponse = response as? HTTPURLResponse {
                                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                                    if acceptFormat == "text/xml" {
                                        do {
                                            let returnedXML = String(data: data!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))! as Any
                                            completion((httpResponse.statusCode,returnedXML))
                                        }
                                    } else {
                                        do {
                                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                                            completion((httpResponse.statusCode,json as Any))
                                        }
                                    }
                                } else {
                                    WriteToLog.shared.message(stringOfText: "[XmlDelegate.apiAction] \(existingDestUrl) lookup encountered an error.  HTTP Status Code: \(httpResponse.statusCode)")
                                    WriteToLog.shared.message(stringOfText: "[XmlDelegate.apiAction] reply: \(String(describing: String(data: data!, encoding: .utf8)))")
                                    completion((httpResponse.statusCode,""))
                                }
                            } else {
                                WriteToLog.shared.message(stringOfText: "[XmlDelegate.apiAction] error getting XML for \(existingDestUrl)")
                                completion((0,""))
                            }   // if let httpResponse - end
                            semaphore.signal()
                            if error != nil {
                            }
                        })  // let task = destSession - end
                        //print("GET")
                        task.resume()
                        
                    } else {
                        WriteToLog.shared.message(stringOfText: "Failed to authenticate to \(existingDestUrl), status code: \(statusCode)")
                        completion((statusCode,""))
                    }
                }
            }   // getRecordQ - end
        } else {
            completion((200,""))
        }
    }
    
//    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
//    }
}

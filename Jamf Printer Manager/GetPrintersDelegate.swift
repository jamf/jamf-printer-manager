//
//  Copyright 2026, Jamf
//

import Cocoa
import Foundation

class GetPrintersDelegate: NSObject, URLSessionDelegate {
    
    static let shared = GetPrintersDelegate()
    private override init() { }

    var endpointPath  = ""

    func apiAction(method: String, theEndpoint: String, acceptFormat: String = "application/json", completion: @escaping (_ result: (Int,Data)) -> Void) {
        
        if theEndpoint.prefix(4) != "skip" {
            let getRecordQ = OperationQueue()
        
            URLCache.shared.removeAllCachedResponses()
            var existingDestUrl = ""
            
            existingDestUrl = "\(JamfProServer.destination)/JSSResource/\(theEndpoint)"
            existingDestUrl = existingDestUrl.urlFix
            
            WriteToLog.shared.message("[GetPrintersDelegate.apiAction] Looking up: \(existingDestUrl)")

            let destEncodedURL = URL(string: existingDestUrl)
            let jsonRequest     = NSMutableURLRequest(url: destEncodedURL! as URL)
            
            let semaphore = DispatchSemaphore(value: 1)
            getRecordQ.maxConcurrentOperationCount = 3
            getRecordQ.addOperation {
                
                TokenDelegate.shared.getToken(serverUrl: JamfProServer.destination, base64creds: JamfProServer.base64Creds) { [self]
                    authResult in
                    let (statusCode,theResult) = authResult
                    if theResult == "success" {
                        
                        jsonRequest.httpMethod = "\(method.uppercased())"
                        let destConf = URLSessionConfiguration.default

                        destConf.httpAdditionalHeaders = ["Authorization" : "\(String(describing: JamfProServer.authType)) \(String(describing: JamfProServer.accessToken))", "Accept" : acceptFormat, "User-Agent" : AppInfo.userAgentHeader]
                        
                        if JamfProServer.sessionCookie.count > 0 && JamfProServer.stickySession {
                            URLSession.shared.configuration.httpCookieStorage!.setCookies(JamfProServer.sessionCookie, for: URL(string: JamfProServer.destination), mainDocumentURL: URL(string: JamfProServer.destination))
                        }
                        let startDate = Date()
                        let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
                        let task = destSession.dataTask(with: jsonRequest as URLRequest, completionHandler: {
                            (data, response, error) -> Void in
                            destSession.finishTasksAndInvalidate()
                            let (_, _, _, tokenAgeInSeconds) = timeDiff(startTime: startDate)
                            WriteToLog.shared.message("[GetPrintersDelegate.apiAction] query time for \(method) on \(existingDestUrl): \(tokenAgeInSeconds) seconds")
                            
                            if let httpResponse = response as? HTTPURLResponse {
                                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299, let myData = data {
//                                    do {
//                                        let _ = try JSONDecoder().decode(JamfProPrinterList.self, from: myData)
////                                        WriteToLog.shared.message("[GetPrintersDelegate.decoded] data as string reply: \(String(describing: String(data: myData, encoding: .utf8) ?? "unknown data"))")
//                                    } catch let DecodingError.keyNotFound(key, context) {
//                                        print("Missing key: \(key.stringValue)")
//                                        print("Path: \(context.codingPath)")
//                                    } catch let DecodingError.typeMismatch(type, context) {
//                                        print("Type mismatch: \(type)")
//                                        print("Path: \(context.codingPath)")
//                                    } catch let DecodingError.valueNotFound(type, context) {
//                                        print("Value not found: \(type)")
//                                        print("Path: \(context.codingPath)")
//                                    } catch {
//                                        print("Error: \(error)")
//                                    }
                                    completion((httpResponse.statusCode, myData))
                                } else {
                                    WriteToLog.shared.message("[GetPrintersDelegate.apiAction] \(existingDestUrl) lookup encountered an error.  HTTP Status Code: \(httpResponse.statusCode)")
                                    WriteToLog.shared.message("[GetPrintersDelegate.apiAction] reply: \(String(describing: String(data: data ?? Data(), encoding: .utf8)))")
                                    completion((httpResponse.statusCode,Data()))
                                }
                            } else {
                                WriteToLog.shared.message("[GetPrintersDelegate.apiAction] error getting JSON for \(existingDestUrl)")
                                completion((0,Data()))
                            }
                            semaphore.signal()
                            if error != nil {
                            }
                        })
                        task.resume()
                        
                    } else {
                        WriteToLog.shared.message("Failed to authenticate to \(existingDestUrl), status code: \(statusCode)")
                        completion((statusCode,Data()))
                    }
                }
            }
        } else {
            completion((200,Data()))
        }
    }
}

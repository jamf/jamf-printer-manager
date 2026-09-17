//
//  Copyright 2026, Jamf
//

import Cocoa

class TokenDelegate: NSObject, URLSessionDelegate {

    static let shared = TokenDelegate()
    private override init() { }

    var components   = DateComponents()
    var renewQ       = DispatchQueue(label: "com.token_refreshQ", qos: DispatchQoS.background)

    func getToken(serverUrl: String, base64creds: String, completion: @escaping (_ authResult: (Int,String)) -> Void) {

        URLCache.shared.removeAllCachedResponses()

        // School API: stateless Basic Auth — no token exchange needed
        if useApiClient == 3 {
            JamfProServer.accessToken  = base64creds
            JamfProServer.base64Creds  = base64creds
            JamfProServer.authType     = "Basic"
            JamfProServer.validToken   = true
            JamfProServer.tokenCreated = Date()
            JamfProServer.authExpires  = 86400
            completion((200, "success"))
            return
        }

        let isPlatform  = (useApiClient == 0)
        let isApiClient = (useApiClient == 1)

        let tokenUrlString: String
        switch useApiClient {
        case 0:  tokenUrlString = "https://\(JamfProServer.region).api.jamfcloud.com/auth/token"
        case 1:  tokenUrlString = "\(serverUrl)/api/oauth/token"
        default: tokenUrlString = "\(serverUrl)/api/v1/auth/token"
        }

        let cleanTokenUrl = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
        guard let tokenUrl = URL(string: cleanTokenUrl) else {
            WriteToLog.shared.message("[getToken] problem constructing the URL from \(cleanTokenUrl)")
            completion((500, "failed"))
            return
        }

        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"

        let (_, _, _, tokenAgeInSeconds) = timeDiff(startTime: JamfProServer.tokenCreated)

        let needNewToken: Bool
        if isPlatform || isApiClient {
            needNewToken = !JamfProServer.validToken || tokenAgeInSeconds >= JamfProServer.authExpires
        } else {
            needNewToken = !(JamfProServer.validToken && tokenAgeInSeconds < JamfProServer.authExpires) || (JamfProServer.base64Creds != base64creds)
        }

        if needNewToken {
            WriteToLog.shared.message("[getToken] tokenAgeInSeconds: \(tokenAgeInSeconds)")
            WriteToLog.shared.message("[getToken] Attempting to retrieve token from \(cleanTokenUrl)")

            if isPlatform || isApiClient {
                let body = "grant_type=client_credentials&client_id=\(JamfProServer.username)&client_secret=\(JamfProServer.password)"
                request.httpBody = body.data(using: .utf8)
                configuration.httpAdditionalHeaders = [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json",
                    "User-Agent": AppInfo.userAgentHeader
                ]
                JamfProServer.currentCred = body
            } else {
                configuration.httpAdditionalHeaders = [
                    "Authorization": "Basic \(base64creds)",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "User-Agent": AppInfo.userAgentHeader
                ]
                JamfProServer.currentCred = base64creds
            }

            let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: { [self]
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    if httpSuccess.contains(httpResponse.statusCode) {
                        if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) {
                            if let endpointJSON = json as? [String: Any] {
                                JamfProServer.accessToken = (isPlatform || isApiClient)
                                    ? (endpointJSON["access_token"] as? String ?? "")
                                    : (endpointJSON["token"] as? String ?? "")

                                JamfProServer.base64Creds = base64creds

                                if isPlatform {
                                    JamfProServer.authExpires = (endpointJSON["expires_in"] as? Double ?? 3600) * 0.75
                                    JamfProServer.tenantId    = serverUrl
                                } else if isApiClient {
                                    JamfProServer.authExpires = (endpointJSON["expires_in"] as? Double ?? 60) * 0.75
                                } else {
                                    JamfProServer.authExpires = ((endpointJSON["expires"] as? Double ?? 30) * 60) * 0.75
                                }

                                JamfProServer.tokenCreated = Date()
                                JamfProServer.validToken   = true
                                JamfProServer.authType     = "Bearer"

                                WriteToLog.shared.message("[getToken] new token created for \(serverUrl)")

                                if isPlatform {
                                    completion((200, "success"))
                                    return
                                }

                                if JamfProServer.version == "" {
                                    getVersion(serverUrl: serverUrl, endpoint: "jamf-pro-version", apiData: [:], id: "", token: JamfProServer.accessToken, method: "GET") {
                                        (result: [String:Any]) in
                                        let versionString = result["version"] as! String

                                        if versionString != "" {
                                            WriteToLog.shared.message("[JamfPro.getVersion] Jamf Pro Version: \(versionString)")
                                            JamfProServer.version = versionString
                                            let tmpArray = versionString.components(separatedBy: ".")
                                            if tmpArray.count > 2 {
                                                for i in 0...2 {
                                                    switch i {
                                                    case 0:
                                                        JamfProServer.majorVersion = Int(tmpArray[i]) ?? 0
                                                    case 1:
                                                        JamfProServer.minorVersion = Int(tmpArray[i]) ?? 0
                                                    case 2:
                                                        let tmp = tmpArray[i].components(separatedBy: "-")
                                                        JamfProServer.patchVersion = Int(tmp[0]) ?? 0
                                                        if tmp.count > 1 {
                                                            JamfProServer.build = tmp[1]
                                                        }
                                                    default:
                                                        break
                                                    }
                                                }
                                                if ( JamfProServer.majorVersion > 10 || (JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34) ) {
                                                    JamfProServer.authType = "Bearer"
                                                    WriteToLog.shared.message("[JamfPro.getVersion] \(serverUrl) set to use OAuth")
                                                } else {
                                                    JamfProServer.authType    = "Basic"
                                                    JamfProServer.accessToken = base64creds
                                                    WriteToLog.shared.message("[JamfPro.getVersion] \(serverUrl) set to use Basic")
                                                }
                                                completion((200, "success"))
                                                return
                                            }
                                        }
                                    }
                                } else {
                                    completion((200, "success"))
                                    return
                                }
                            } else {
                                WriteToLog.shared.message("[getToken] JSON error.\n\(String(describing: json))")
                                JamfProServer.validToken = false
                                completion((httpResponse.statusCode, "failed"))
                                return
                            }
                        } else {
                            _ = Alert.shared.display(header: "", message: "Failed to get an expected response from \(cleanTokenUrl).", secondButton: "")
                            WriteToLog.shared.message("[TokenDelegate.getToken] Failed to get an expected response from \(cleanTokenUrl).  Status Code: \(httpResponse.statusCode)")
                            JamfProServer.validToken = false
                            completion((httpResponse.statusCode, "failed"))
                            return
                        }
                    } else {
                        _ = Alert.shared.display(header: "\(cleanTokenUrl)", message: "Failed to authenticate. \nStatus Code: \(httpResponse.statusCode)", secondButton: "")
                        WriteToLog.shared.message("[getToken] Failed to authenticate to \(cleanTokenUrl).  Response error: \(httpResponse.statusCode)")
                        JamfProServer.validToken = false
                        completion((httpResponse.statusCode, "failed"))
                        return
                    }
                } else {
                    _ = Alert.shared.display(header: "\(cleanTokenUrl)", message: "Failed to connect. \nUnknown error, verify url and port.", secondButton: "")
                    WriteToLog.shared.message("[getToken] token response error from \(cleanTokenUrl).  Verify url and port")
                    JamfProServer.validToken = false
                    completion((0, "failed"))
                    return
                }
            })
            task.resume()
        } else {
            completion((200, "success"))
            return
        }
    }

    func getVersion(serverUrl: String, endpoint: String, apiData: [String:Any], id: String, token: String, method: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {

        if method.lowercased() == "skip" {
            let JPAPI_result = (endpoint == "auth/invalidate-token") ? "no valid token":"failed"
            completion(["JPAPI_result":JPAPI_result, "JPAPI_response":000])
            return
        }

        URLCache.shared.removeAllCachedResponses()
        var path = ""

        switch endpoint {
        case  "buildings", "csa/token", "icon", "jamf-pro-version", "auth/invalidate-token":
            path = "v1/\(endpoint)"
        default:
            path = "v2/\(endpoint)"
        }

        var urlString = "\(serverUrl)/api/\(path)"
        urlString     = urlString.replacingOccurrences(of: "//api", with: "/api")
        if id != "" && id != "0" {
            urlString = urlString + "/\(id)"
        }

        let url            = URL(string: "\(urlString)")
        let configuration  = URLSessionConfiguration.default
        var request        = URLRequest(url: url!)
        switch method.lowercased() {
        case "get":
            request.httpMethod = "GET"
        case "create", "post":
            request.httpMethod = "POST"
        default:
            request.httpMethod = "PUT"
        }

        if apiData.count > 0 {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: apiData, options: .prettyPrinted)
            } catch let error {
                WriteToLog.shared.message("[Jpapi.action] Error serializing JSON: \(error.localizedDescription)")
            }
        }

        WriteToLog.shared.message("[Jpapi.action] Attempting \(method) on \(urlString).")

        if useApiClient == 0 {
            configuration.httpAdditionalHeaders = [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": AppInfo.userAgentHeader,
                "X-Tenant-Id": JamfProServer.tenantId
            ]
        } else {
            configuration.httpAdditionalHeaders = [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": AppInfo.userAgentHeader
            ]
        }

        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {

                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json as? [String:Any] {
                        completion(endpointJSON)
                        return
                    } else {
                        if httpResponse.statusCode == 204 && endpoint == "auth/invalidate-token" {
                            completion(["JPAPI_result":"token terminated", "JPAPI_response":httpResponse.statusCode])
                        } else {
                            completion(["JPAPI_result":"failed", "JPAPI_response":httpResponse.statusCode])
                        }
                        return
                    }
                } else {
                    WriteToLog.shared.message("[TokenDelegate.getVersion] Response error: \(httpResponse.statusCode).")
                    completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? method, "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                    return
                }
            } else {
                WriteToLog.shared.message("[TokenDelegate.getVersion] GET response error.  Verify url and port.")
                completion([:])
                return
            }
        })
        task.resume()

    }
}

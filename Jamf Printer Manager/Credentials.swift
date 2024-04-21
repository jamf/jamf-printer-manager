//
//  Copyright 2023 jamf. All rights reserved.
//

import Foundation
import Security

let kSecAttrAccountString          = NSString(format: kSecAttrAccount)
let kSecValueDataString            = NSString(format: kSecValueData)
let kSecClassGenericPasswordString = NSString(format: kSecClassGenericPassword)
let keychainQ                      = DispatchQueue(label: "com.jamf.creds", qos: DispatchQoS.background)
let prefix                         = "JamfPrinterManager"
let sharedPrefix                   = "JSK"
let accessGroup                    = "483DWKW443.jamfie.SharedJSK"


class Credentials {
    
    static let shared = Credentials()
    private init() { }
    
    var userPassDict = [String:String]()
    
    func save(service: String, account: String, credential: String) {
        if service != "" && account != "" {
            var theService = service
            if useApiClient == 1 {
                theService = "apiClient-" + theService
            }
            let keychainItemName = sharedPrefix + "-" + theService
            if let password = credential.data(using: String.Encoding.utf8) {
                keychainQ.async { [self] in
                    var keychainQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                                        kSecAttrService as String: keychainItemName,
                                                        kSecAttrAccessGroup as String: accessGroup,
                                                        kSecUseDataProtectionKeychain as String: true,
                                                        kSecAttrAccount as String: account,
                                                        kSecValueData as String: password]
                    
                    // see if credentials already exist for server
                    let accountCheck = retrieve(service: service, account: account)
                    if accountCheck.count == 0 {
                        // try to add new credentials, if account exists we'll try updating it
                        let addStatus = SecItemAdd(keychainQuery as CFDictionary, nil)
                        if (addStatus != errSecSuccess) {
                            if let addErr = SecCopyErrorMessageString(addStatus, nil) {
                                print("[addStatus] Write failed for new credentials: \(addErr)")
                                let deleteStatus = SecItemDelete(keychainQuery as CFDictionary)
                                print("[Credentials.save] the deleteStatus: \(deleteStatus)")
                                sleep(1)
                                let addStatus = SecItemAdd(keychainQuery as CFDictionary, nil)
                                if (addStatus != errSecSuccess) {
                                    if let addErr = SecCopyErrorMessageString(addStatus, nil) {
                                        print("[addStatus] Write failed for new credentials after deleting: \(addErr)")
                                    }
                                }
                            }
                        }
                    } else {
                        // credentials already exist, try to update
                        keychainQuery = [kSecClass as String: kSecClassGenericPasswordString,
                                         kSecAttrService as String: keychainItemName,
                                         kSecMatchLimit as String: kSecMatchLimitOne,
                                         kSecReturnAttributes as String: true]
                        
                        for (username, password) in accountCheck {
                            if account != username || credential != password {
                                // credentials already exist, try to update
                                if account == username {
                                    let updateStatus = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueDataString:password] as [NSString : Any] as CFDictionary)
//                                    print("[Credentials.save] updateStatus result: \(updateStatus)")
                                } else {
//                                    print("[addStatus] save password for: \(account)")
                                    let addStatus = SecItemAdd(keychainQuery as CFDictionary, nil)
                                    if (addStatus != errSecSuccess) {
                                        if let addErr = SecCopyErrorMessageString(addStatus, nil) {
                                            print("[addStatus] Write failed for new credentials: \(addErr)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func retrieve(service: String, account: String, whichServer: String = "") -> [String:String] {
        var keychainResult = [String:String]()
        var theService     = service
//        var keychainName   = "JSK-\(service)"
        
        if useApiClient == 1 {
            theService = "apiClient-" + theService
        }
        var keychainItemName = sharedPrefix + "-" + theService
//        print("[credentials] lookup for \(account), keychainItemName: \(keychainItemName)")
        // look for common keychain item
        keychainResult = itemLookup(service: keychainItemName)
        
        return keychainResult
    }
    
    private func itemLookup(service: String) -> [String:String] {
        
//        print("[Credentials.itemLookup] start search for: \(service)")
   
        let keychainQuery: [String: Any] = [kSecClass as String: kSecClassGenericPasswordString,
                                            kSecAttrService as String: service,
                                            kSecAttrAccessGroup as String: accessGroup,
                                            kSecUseDataProtectionKeychain as String: true,
                                            kSecMatchLimit as String: kSecMatchLimitAll,
                                            kSecReturnAttributes as String: true,
                                            kSecReturnData as String: true]
        
        var items_ref: CFTypeRef?
        
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &items_ref)
        guard status != errSecItemNotFound else {
            print("[Credentials.itemLookup] lookup error occurred for \(service): \(status.description)")
            return [:]
            
        }
        guard status == errSecSuccess else { return [:] }
        
        guard let items = items_ref as? [[String: Any]] else {
            print("[Credentials.itemLookup] unable to read keychain item: \(service)")
            return [:]
        }
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String, let passwordData = item[kSecValueData as String] as? Data {
                let password = String(data: passwordData, encoding: String.Encoding.utf8)
                userPassDict[account] = password ?? ""
            }
        }

//        print("[Credentials.itemLookup] keychain item count: \(userPassDict.count) for \(service)")
        return userPassDict
    }
}

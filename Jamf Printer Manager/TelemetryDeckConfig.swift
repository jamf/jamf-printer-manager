//
//  Copyright 2026, Jamf
//

import TelemetryDeck

struct TelemetryDeckConfig {
    static let appId = "<your app id>"
    @MainActor static var parameters: [String: String] = [:]
    @MainActor static var optOut: Bool = false
}

extension AppDelegate {
    @MainActor func configureTelemetryDeck() {
        if !TelemetryDeckConfig.optOut {
            let config = TelemetryDeck.Config(appID: TelemetryDeckConfig.appId)
            TelemetryDeck.initialize(config: config)
        }
    }
}

class TelemetryDeckSignal {
    static let shared = TelemetryDeckSignal()
    private init() {}
    
    @MainActor func send(_ event: String, parameters: [String: String] = [:]) {
        if !TelemetryDeckConfig.optOut {
            TelemetryDeck.signal(event, parameters: parameters)
        }
    }
}

import Foundation
import Observation
import ServiceManagement

/// Global app settings, persisted to UserDefaults.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// Gap in points between zones when snapping.
    var zoneGap: Double {
        didSet { UserDefaults.standard.set(zoneGap, forKey: "zoneGap") }
    }

    /// Whether to animate window snapping.
    var animateSnap: Bool {
        didSet { UserDefaults.standard.set(animateSnap, forKey: "animateSnap") }
    }

    /// Launch at login.
    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    /// Enable edge snapping (drag to screen edge without modifier).
    var edgeSnapEnabled: Bool {
        didSet { UserDefaults.standard.set(edgeSnapEnabled, forKey: "edgeSnapEnabled") }
    }

    /// Edge snap trigger distance in points.
    var edgeSnapThreshold: Double {
        didSet { UserDefaults.standard.set(edgeSnapThreshold, forKey: "edgeSnapThreshold") }
    }

    /// Delay in seconds before edge snap triggers.
    var edgeSnapDelay: Double {
        didSet { UserDefaults.standard.set(edgeSnapDelay, forKey: "edgeSnapDelay") }
    }

    private init() {
        let defaults = UserDefaults.standard
        // Register defaults
        defaults.register(defaults: [
            "zoneGap": 0.0,
            "animateSnap": true,
            "launchAtLogin": false,
            "edgeSnapEnabled": false,
            "edgeSnapThreshold": 5.0,
            "edgeSnapDelay": 0.3,
        ])
        self.zoneGap = defaults.double(forKey: "zoneGap")
        self.animateSnap = defaults.bool(forKey: "animateSnap")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.edgeSnapEnabled = defaults.bool(forKey: "edgeSnapEnabled")
        self.edgeSnapThreshold = defaults.double(forKey: "edgeSnapThreshold")
        self.edgeSnapDelay = defaults.double(forKey: "edgeSnapDelay")
    }

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("[EpycZones] Login item error: %@", error.localizedDescription)
            }
        }
    }
}

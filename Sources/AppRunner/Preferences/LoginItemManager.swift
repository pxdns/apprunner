import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService so the rest of the app doesn't touch
/// ServiceManagement directly.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("AppRunner: failed to update login item — \(error.localizedDescription)")
        }
    }
}

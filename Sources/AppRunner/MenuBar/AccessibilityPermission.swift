import ApplicationServices

/// Reading and interacting with another app's menu bar requires the user to
/// grant AppRunner Accessibility access (System Settings → Privacy &
/// Security → Accessibility) — the same standard, revocable permission
/// used by window managers and hotkey utilities. No entitlement, no SIP
/// changes, nothing that touches other apps' files.
enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestIfNeeded() -> Bool {
        let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

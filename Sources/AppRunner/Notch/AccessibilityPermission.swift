import ApplicationServices

/// Reading whether the frontmost window is fullscreen (so the notch panel
/// can get out of the way) requires Accessibility access — the same
/// standard, revocable, user-visible permission (System Settings →
/// Privacy & Security → Accessibility) window managers and hotkey
/// utilities use. Nothing here writes to or controls other apps.
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

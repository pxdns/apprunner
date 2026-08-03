import AppKit
import ApplicationServices

/// Polls whether the frontmost app's focused window is fullscreen, via
/// the Accessibility API's `AXFullScreen` attribute (a real, documented
/// attribute most fullscreen-capable apps expose — no private API here).
/// Used to hide the notch panel while a fullscreen app is active, the way
/// the real menu bar disappears in that situation too.
///
/// Without Accessibility permission granted, `AXUIElementCopyAttributeValue`
/// simply fails and this reports `false` (never fullscreen) — the notch
/// just stays visible as before, no crash, no prompt loop.
@MainActor
final class FullScreenMonitor {
    private(set) var isFullScreen = false
    var onChange: ((Bool) -> Void)?

    private var timer: Timer?

    func start(interval: TimeInterval = 0.75) {
        guard timer == nil else { return }
        check()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.check() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        let newValue = Self.frontmostWindowIsFullScreen()
        guard newValue != isFullScreen else { return }
        isFullScreen = newValue
        onChange?(newValue)
    }

    private static func frontmostWindowIsFullScreen() -> Bool {
        guard AccessibilityPermission.isTrusted,
              let app = NSWorkspace.shared.frontmostApplication
        else { return false }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRaw = windowRef
        else { return false }
        let window = windowRaw as! AXUIElement

        var fullScreenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fullScreenRef) == .success else {
            return false
        }
        return (fullScreenRef as? Bool) ?? false
    }
}

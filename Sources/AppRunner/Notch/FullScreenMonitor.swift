import AppKit
import ApplicationServices
import CoreGraphics

/// Polls whether a fullscreen app is active, hiding the notch panel while
/// one is — the way the real menu bar disappears in that situation too.
/// Two independent checks, either one triggering counts:
///
/// 1. Accessibility's `AXFullScreen` attribute on the frontmost app's
///    focused window (a real, documented attribute) — but this reports
///    nothing (silently `false`) if Accessibility permission was never
///    actually granted, which is easy to miss/dismiss on first launch.
/// 2. A permission-free fallback: `CGWindowListCopyWindowInfo` — any
///    on-screen, normal-layer window whose bounds cover the *entire*
///    screen (including where the menu bar normally is) is almost
///    certainly a fullscreen app's window. Works regardless of whether
///    Accessibility access was granted.
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
        let newValue = Self.axFullScreen() || Self.windowCoversScreen()
        guard newValue != isFullScreen else { return }
        isFullScreen = newValue
        onChange?(newValue)
    }

    private static func axFullScreen() -> Bool {
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

    private static func windowCoversScreen() -> Bool {
        guard let screen = NSScreen.main else { return false }
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        let screenWidth = screen.frame.width
        let screenHeight = screen.frame.height

        for window in list {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = bounds["Width"], let height = bounds["Height"]
            else { continue }

            // A normal-layer window whose bounds span the *entire* screen
            // (including under the menu bar) is a fullscreen app's window
            // — regular windows never extend under the menu bar.
            if width >= screenWidth - 1 && height >= screenHeight - 1 {
                return true
            }
        }
        return false
    }
}

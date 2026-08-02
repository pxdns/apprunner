import AppKit
import SwiftUI

enum NotchDisplayState: Equatable {
    case closed
    case hover
    case open
}

/// Owns the NotchPanel and keeps it pinned under the menu bar / display
/// notch. The window itself is created ONCE at a fixed size big enough
/// for the largest state and never resized again — all closed/hover/open
/// sizing happens purely inside SwiftUI (NotchContentView), animating the
/// inner shape rather than the window frame. Resizing an actual NSWindow
/// while the mouse is hovering over it causes the cursor to fall outside
/// the frame mid-animation, which fires a spurious hover-exit, which
/// shrinks it back, which re-triggers hover — a visible flicker loop.
/// Keeping the window fixed-size sidesteps that entirely.
@MainActor
final class NotchController {
    private var panel: NotchPanel?
    private let settings: NotchSettingsStore

    init(settings: NotchSettingsStore) {
        self.settings = settings
    }

    func show() {
        guard let screen = NSScreen.main else {
            NSLog("AppRunner: NotchController.show() — NSScreen.main is nil, cannot place notch")
            return
        }
        let canvasSize = NotchGeometry.maxCanvasSize(for: screen, settings: settings)
        let origin = NSPoint(
            x: screen.frame.midX - canvasSize.width / 2,
            y: screen.frame.maxY - canvasSize.height
        )
        let rect = NSRect(origin: origin, size: canvasSize)
        let panel = NotchPanel(contentRect: rect)

        let content = NotchContentView(settings: settings)
        panel.contentView = NSHostingView(rootView: content)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// ⌥ Space: show/hide the whole notch panel.
    func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }
}

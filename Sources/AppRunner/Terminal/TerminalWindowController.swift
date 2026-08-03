import AppKit
import SwiftUI

/// A real, standalone, resizable terminal window — not trapped inside the
/// notch's small fixed panel. Reuses the same TerminalPaneView (terminal +
/// theme picker) the notch used to show in its Terminal tab.
@MainActor
final class TerminalWindowController: NSWindowController {
    convenience init(settings: NotchSettingsStore) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Terminal"
        window.minSize = NSSize(width: 360, height: 220)
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: TerminalPaneView(settings: settings).colorScheme(.dark))
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

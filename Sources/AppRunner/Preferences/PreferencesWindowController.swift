import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "AppRunner Preferences"
        window.center()
        window.contentView = NSHostingView(rootView: PreferencesView())
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

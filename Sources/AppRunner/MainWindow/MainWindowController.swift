import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController {
    convenience init(appLibrary: AppLibrary, menuBarStore: MenuBarCustomizationStore) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AppRunner"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: MainWindowView(appLibrary: appLibrary, menuBarStore: menuBarStore)
        )
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

import SwiftUI
import AppKit

/// Entry point. AppRunner has no Dock icon (LSUIElement); its whole UI is
/// the notch panel — a real terminal plus notch customization, nothing else.
@main
struct AppRunnerMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var notchController: NotchController?
    private var hotKeyManager: HotKeyManager?
    private let settings = NotchSettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Powers hiding the notch during fullscreen apps; stays inert
        // (notch just never auto-hides) if this is denied.
        AccessibilityPermission.requestIfNeeded()

        notchController = NotchController(settings: settings)
        notchController?.show()

        // ⌥ Space toggles the notch without touching the mouse.
        hotKeyManager = HotKeyManager { [weak self] in
            self?.notchController?.toggle()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "AppRunner")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Notch (⌥Space)", action: #selector(toggleNotch), keyEquivalent: "n")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit AppRunner", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items {
            item.target = self
        }
        statusItem?.menu = menu
    }

    @objc private func toggleNotch() {
        notchController?.toggle()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

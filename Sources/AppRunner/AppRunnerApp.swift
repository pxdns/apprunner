import SwiftUI
import AppKit

/// Entry point. AppRunner has no Dock icon (LSUIElement) but does open a
/// normal, visible window on launch — the notch panel is an additional
/// hover-only quick-access shortcut, not the only way to reach the app.
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
    private var preferencesController: PreferencesWindowController?
    private var mainWindowController: MainWindowController?
    private let appLibrary = AppLibrary()
    private let menuBarStore = MenuBarCustomizationStore()
    private let menuBarOverlay: MenuBarOverlayController
    private let menuBarClickGuard = MenuBarClickGuard()

    override init() {
        menuBarOverlay = MenuBarOverlayController(store: menuBarStore)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        appLibrary.refresh()

        // Always show a normal, visible window on launch — the notch is a
        // hover-only convenience layered on top, and easy to miss if you
        // don't already know it's there.
        mainWindowController = MainWindowController(appLibrary: appLibrary, menuBarStore: menuBarStore)
        mainWindowController?.show()

        notchController = NotchController(appLibrary: appLibrary, menuBarStore: menuBarStore)
        notchController?.show()

        // ⌥ Space toggles the notch without touching the mouse.
        hotKeyManager = HotKeyManager { [weak self] in
            self?.notchController?.toggle()
        }

        // Menu bar hide/rename: prompts once for Accessibility access; both
        // pieces stay inert (no-ops) until that's granted.
        AccessibilityPermission.requestIfNeeded()
        menuBarOverlay.start()
        menuBarClickGuard.hiddenRectsProvider = { [weak self] in
            self?.menuBarOverlay.currentHiddenRects ?? []
        }
        menuBarClickGuard.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.compress.vertical", accessibilityDescription: "AppRunner")
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Show AppRunner Window", action: #selector(showMainWindow), keyEquivalent: "a")
        menu.addItem(withTitle: "Toggle Notch (⌥Space)", action: #selector(toggleNotch), keyEquivalent: "n")
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit AppRunner", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items {
            item.target = self
        }
        statusItem?.menu = menu
    }

    @objc private func showMainWindow() {
        mainWindowController?.show()
    }

    @objc private func toggleNotch() {
        notchController?.toggle()
    }

    @objc private func openPreferences() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController()
        }
        preferencesController?.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

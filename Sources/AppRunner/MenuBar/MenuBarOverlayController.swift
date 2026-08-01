import AppKit
import CoreGraphics
import SwiftUI

/// Owns the transparent, click-through overlay panel that visually patches
/// another app's menu bar. The panel is purely cosmetic (`ignoresMouseEvents
/// = true`); `MenuBarClickGuard` is what actually makes hidden items
/// unclickable. Nothing here writes to disk outside AppRunner's own
/// preferences, and the target app's bundle/process is never modified.
@MainActor
final class MenuBarOverlayController {
    private let store: MenuBarCustomizationStore
    private var window: NSPanel?
    private var timer: Timer?

    /// Screen-space rects (Accessibility coordinate space, top-left origin)
    /// of currently-hidden items, read by MenuBarClickGuard to swallow clicks.
    private(set) var currentHiddenRects: [CGRect] = []

    init(store: MenuBarCustomizationStore) {
        self.store = store
    }

    private var activationObserver: NSObjectProtocol?

    func start() {
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        activationObserver = nil
        window?.orderOut(nil)
    }

    private func refresh() {
        guard AccessibilityPermission.isTrusted,
              let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontmost.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier,
              let appRules = store.rules[bundleID], !appRules.isEmpty,
              let screen = NSScreen.screens.first
        else {
            hide()
            return
        }

        let items = MenuBarInspector.menuBarItems(for: frontmost.processIdentifier)
        var entries: [MenuBarOverlayEntry] = []
        var hiddenRects: [CGRect] = []

        for item in items {
            guard let rule = appRules[item.title], !rule.isNoOp else { continue }
            entries.append(MenuBarOverlayEntry(item: item, rule: rule))
            if rule.hidden { hiddenRects.append(item.frame) }
        }

        currentHiddenRects = hiddenRects
        guard !entries.isEmpty else { hide(); return }
        show(entries: entries, screen: screen)
    }

    private func hide() {
        currentHiddenRects = []
        window?.orderOut(nil)
    }

    private func show(entries: [MenuBarOverlayEntry], screen: NSScreen) {
        let menuBarHeight: CGFloat = 24
        let frame = NSRect(x: 0, y: screen.frame.maxY - menuBarHeight, width: screen.frame.width, height: menuBarHeight)

        let panel: NSPanel
        if let existing = window {
            panel = existing
        } else {
            panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window = panel
        }

        panel.setFrame(frame, display: false)
        panel.contentView = NSHostingView(rootView: MenuBarOverlayView(entries: entries))
        panel.orderFrontRegardless()
    }
}

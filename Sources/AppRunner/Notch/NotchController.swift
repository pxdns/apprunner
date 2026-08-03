import AppKit
import SwiftUI
import Combine

enum NotchDisplayState: Equatable {
    case resting
    case preview
    case open
}

/// Owns the NotchPanel and keeps it pinned under the menu bar / display
/// notch. The window itself is created ONCE at a fixed size big enough
/// for the largest state and never resized again — all resting/preview/
/// open sizing happens purely inside SwiftUI (NotchContentView),
/// animating the inner shape rather than the window frame. Resizing an
/// actual NSWindow while the mouse is hovering over it causes the cursor
/// to fall outside the frame mid-animation, which fires a spurious
/// hover-exit, which shrinks it back, which re-triggers hover — a visible
/// flicker loop. Keeping the window fixed-size sidesteps that entirely.
/// Repositioning (drag-to-move) is a different, safe operation — see
/// repositionPanel() — since it's user-initiated and doesn't touch size.
@MainActor
final class NotchController {
    private var panel: NotchPanel?
    private let settings: NotchSettingsStore
    private let fullScreenMonitor = FullScreenMonitor()
    private let navigator = NotchNavigator()
    private var cancellables = Set<AnyCancellable>()

    /// Two independent reasons the panel might be off-screen: the user
    /// explicitly hid it (⌥ Space), or a fullscreen app is active (the
    /// real menu bar disappears then too, so the notch should match).
    /// Visible only when neither is true.
    private var userHidden = false

    init(settings: NotchSettingsStore) {
        self.settings = settings
    }

    func show() {
        guard let screen = NSScreen.main else {
            NSLog("AppRunner: NotchController.show() — NSScreen.main is nil, cannot place notch")
            return
        }
        let canvasSize = NotchGeometry.maxCanvasSize(for: screen, settings: settings)
        let rect = NSRect(origin: .zero, size: canvasSize)
        let panel = NotchPanel(contentRect: rect)

        let content = NotchContentView(settings: settings, navigator: navigator)
        panel.contentView = NSHostingView(rootView: content)
        self.panel = panel
        repositionPanel()
        panel.orderFrontRegardless()

        fullScreenMonitor.onChange = { [weak self] _ in
            self?.updateVisibility()
        }
        fullScreenMonitor.start()

        Publishers.CombineLatest(settings.$offsetX, settings.$offsetY)
            .dropFirst() // initial values already applied by the first repositionPanel() above
            .sink { [weak self] _, _ in self?.repositionPanel() }
            .store(in: &cancellables)
    }

    /// ⌥ Space: show/hide the whole notch panel.
    func toggle() {
        userHidden.toggle()
        updateVisibility()
    }

    /// Opens the notch directly to a given tab — used by the status bar
    /// menu's "Open Media"/"Open Settings" items.
    func open(tab: NotchTab) {
        userHidden = false
        updateVisibility()
        navigator.open(tab)
    }

    private func repositionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2 + CGFloat(settings.offsetX),
            y: screen.frame.maxY - size.height - CGFloat(settings.offsetY)
        )
        panel.setFrameOrigin(origin)
    }

    private func updateVisibility() {
        guard let panel else { return }
        let shouldShow = !userHidden && !fullScreenMonitor.isFullScreen
        if shouldShow && !panel.isVisible {
            panel.orderFrontRegardless()
        } else if !shouldShow && panel.isVisible {
            panel.orderOut(nil)
        }
    }
}

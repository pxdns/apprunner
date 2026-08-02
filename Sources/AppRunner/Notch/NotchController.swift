import AppKit
import SwiftUI
import Combine

enum NotchDisplayState: Equatable {
    case closed
    case hover
    case open
}

/// Owns the NotchPanel, keeps it pinned under the menu bar / display notch,
/// and re-sizes it as the notch moves between closed → hover → open.
@MainActor
final class NotchController {
    private var panel: NotchPanel?
    private let settings: NotchSettingsStore
    private let state = CurrentValueSubject<NotchDisplayState, Never>(.closed)

    /// Sized to the *real* physical notch when one exists (via the public
    /// safeAreaInsets/auxiliaryTopLeftArea+auxiliaryTopRightArea APIs,
    /// available macOS 12+), so on a notched machine like an M2 MacBook
    /// Air this exactly matches the camera housing's cutout instead of a
    /// guessed constant. Falls back to a reasonable fixed size on displays
    /// with no physical notch (external monitors, older Macs).
    private func closedSize(for screen: NSScreen) -> NSSize {
        let height = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 26
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return NSSize(width: max(width, 120), height: height)
        }
        return NSSize(width: 200, height: height)
    }

    /// Wider than the physical notch by an equal amount on each side, and
    /// a bit taller — the "something's happening, hover to peek" size.
    private func hoverSize(for screen: NSScreen) -> NSSize {
        let closed = closedSize(for: screen)
        let padding = CGFloat(settings.hoverSidePadding)
        return NSSize(width: closed.width + padding * 2, height: max(closed.height, 64))
    }

    private var openSize: NSSize {
        NSSize(width: CGFloat(settings.expandedWidth), height: CGFloat(settings.expandedHeight))
    }

    init(settings: NotchSettingsStore) {
        self.settings = settings
    }

    func show() {
        guard let screen = NSScreen.main else {
            NSLog("AppRunner: NotchController.show() — NSScreen.main is nil, cannot place notch")
            return
        }
        let size = closedSize(for: screen)

        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        let rect = NSRect(origin: origin, size: size)
        let panel = NotchPanel(contentRect: rect)

        let stateBinding = Binding<NotchDisplayState>(
            get: { [weak self] in self?.state.value ?? .closed },
            set: { [weak self] newValue in self?.setState(newValue) }
        )

        let content = NotchContentView(settings: settings, displayState: stateBinding)
        panel.contentView = NSHostingView(rootView: content)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// ⌥ Space: show/hide the whole notch panel. Whether it shows closed,
    /// hover, or open depends on the mouse/click state SwiftUI already
    /// tracks internally — this only controls whether the panel is on
    /// screen at all, so there's no risk of the window's size and the
    /// SwiftUI content's idea of its own state getting out of sync.
    func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func setState(_ newState: NotchDisplayState) {
        state.send(newState)
        guard let panel, let screen = NSScreen.main else { return }
        let size: NSSize
        switch newState {
        case .closed: size = closedSize(for: screen)
        case .hover: size = hoverSize(for: screen)
        case .open: size = openSize
        }
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}

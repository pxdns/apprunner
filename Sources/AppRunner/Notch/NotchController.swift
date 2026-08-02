import AppKit
import SwiftUI
import Combine

/// Owns the NotchPanel, keeps it pinned under the menu bar / display notch,
/// and re-sizes it as the SwiftUI content expands or collapses.
@MainActor
final class NotchController {
    private var panel: NotchPanel?
    private let settings: NotchSettingsStore
    private let isExpanded = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()

    /// Sized to the *real* physical notch when one exists (via the public
    /// safeAreaInsets/auxiliaryTopLeftArea+auxiliaryTopRightArea APIs,
    /// available macOS 12+), so on a notched machine like an M2 MacBook
    /// Air this exactly matches the camera housing's cutout instead of a
    /// guessed constant. Falls back to a reasonable fixed size on displays
    /// with no physical notch (external monitors, older Macs).
    private func collapsedSize(for screen: NSScreen) -> NSSize {
        let height = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 26
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return NSSize(width: max(width, 120), height: height)
        }
        return NSSize(width: 200, height: height)
    }

    private var expandedSize: NSSize {
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
        let size = collapsedSize(for: screen)
        NSLog("AppRunner: placing notch on \(screen.localizedName), collapsedSize=\(size), safeAreaInsets.top=\(screen.safeAreaInsets.top)")

        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        let rect = NSRect(origin: origin, size: size)
        let panel = NotchPanel(contentRect: rect)

        let expandedBinding = Binding<Bool>(
            get: { [weak self] in self?.isExpanded.value ?? false },
            set: { [weak self] newValue in self?.setExpanded(newValue) }
        )

        let content = NotchContentView(settings: settings, isExpanded: expandedBinding)
        panel.contentView = NSHostingView(rootView: content)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func setExpanded(_ expanded: Bool) {
        isExpanded.send(expanded)
        guard let panel, let screen = NSScreen.main else { return }
        let size = expanded ? expandedSize : collapsedSize(for: screen)
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
    }
}

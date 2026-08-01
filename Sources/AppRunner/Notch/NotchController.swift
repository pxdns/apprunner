import AppKit
import SwiftUI
import Combine

/// Owns the NotchPanel, keeps it pinned under the menu bar / display notch,
/// and re-sizes it as the SwiftUI content expands or collapses.
@MainActor
final class NotchController {
    private var panel: NotchPanel?
    private let appLibrary: AppLibrary
    private let menuBarStore: MenuBarCustomizationStore
    private let isExpanded = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()

    private let collapsedSize = NSSize(width: 170, height: 26)
    private let expandedSize = NSSize(width: 320, height: 340)

    init(appLibrary: AppLibrary, menuBarStore: MenuBarCustomizationStore) {
        self.appLibrary = appLibrary
        self.menuBarStore = menuBarStore
    }

    func show() {
        guard let screen = NSScreen.main else {
            NSLog("AppRunner: NotchController.show() — NSScreen.main is nil, cannot place notch")
            return
        }
        NSLog("AppRunner: placing notch on screen \(screen.localizedName), frame=\(screen.frame), safeAreaInsets.top=\(screen.safeAreaInsets.top)")

        let origin = NSPoint(
            x: screen.frame.midX - collapsedSize.width / 2,
            y: screen.frame.maxY - collapsedSize.height
        )
        let rect = NSRect(origin: origin, size: collapsedSize)
        let panel = NotchPanel(contentRect: rect)

        let expandedBinding = Binding<Bool>(
            get: { [weak self] in self?.isExpanded.value ?? false },
            set: { [weak self] newValue in self?.setExpanded(newValue) }
        )

        let content = NotchContentView(appLibrary: appLibrary, menuBarStore: menuBarStore, isExpanded: expandedBinding)
        panel.contentView = NSHostingView(rootView: content)
        panel.orderFrontRegardless()
        self.panel = panel
        NSLog("AppRunner: notch panel frame=\(panel.frame), isVisible=\(panel.isVisible), level=\(panel.level.rawValue)")
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
        let size = expanded ? expandedSize : collapsedSize
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
    }
}

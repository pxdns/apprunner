import AppKit

/// Borderless, non-activating panel that floats above everything else and
/// tracks the display notch area, the way "boring notch"-style utilities do.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // .screenSaver is a standard, documented "float above essentially
        // everything, including the menu bar" level — the same class of
        // level real always-on-top overlay utilities use. (.statusBar
        // sits below the real system menu bar in this exact screen region
        // and is invisible there; an arbitrary CGWindowLevelKey-derived
        // value can behave oddly with WindowServer compositing.)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

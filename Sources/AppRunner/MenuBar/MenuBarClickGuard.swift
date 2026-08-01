import ApplicationServices
import CoreGraphics
import Foundation

/// Swallows mouse clicks that land on a menu item AppRunner is hiding, so
/// "hidden" isn't just a visual patch — the item genuinely stops opening.
/// Renamed-but-not-hidden items are left alone: clicks pass straight
/// through to the real app, which opens its real (unrenamed) submenu, so
/// functionality is untouched — only the label changed.
///
/// Uses a CGEventTap, the same public, Accessibility-permission-gated
/// mechanism hotkey and window-management utilities use. It only inspects
/// click coordinates against rects AppRunner itself computed; it never
/// reads keystrokes or other apps' content.
final class MenuBarClickGuard {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Supplied by MenuBarOverlayController; called on the tap's callback
    /// thread so it must be cheap and non-blocking.
    var hiddenRectsProvider: @MainActor () -> [CGRect] = { [] }

    func start() {
        guard AccessibilityPermission.isTrusted else { return }
        guard eventTap == nil else { return }

        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let guardInstance = Unmanaged<MenuBarClickGuard>.fromOpaque(userInfo).takeUnretainedValue()
                let location = event.location
                // This tap's run loop source was added on the main thread,
                // so it always fires there — safe to assume main-actor.
                let blocked = MainActor.assumeIsolated {
                    guardInstance.hiddenRectsProvider().contains { $0.contains(location) }
                }
                return blocked ? nil : Unmanaged.passRetained(event)
            },
            userInfo: refcon
        ) else { return }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}

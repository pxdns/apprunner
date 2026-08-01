import Carbon
import AppKit

/// Registers a single system-wide hotkey (default ⌥Space) via the Carbon
/// Event Manager, which is still the only public API for global hotkeys
/// that doesn't require Accessibility permission. Used to summon/dismiss
/// the notch without moving the mouse to the top of the screen.
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: @MainActor () -> Void

    private static let signature: OSType = 0x4152_4B59 // 'ARKY'
    private static let hotKeyID = UInt32(1)

    init(keyCode: UInt32 = UInt32(kVK_Space), modifiers: UInt32 = UInt32(optionKey), handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        register(keyCode: keyCode, modifiers: modifiers)
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                // Carbon dispatches this on the application's main event
                // target, which always runs on the main thread/main actor.
                MainActor.assumeIsolated {
                    manager.handler()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

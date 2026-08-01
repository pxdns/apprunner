import ApplicationServices
import Foundation

/// One top-level menu bar entry for another app — this includes the bold
/// application-name menu itself (e.g. "Chrome"), not just File/Edit/View,
/// since macOS exposes it as just another AXMenuBarItem.
struct MenuBarItemInfo: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let frame: CGRect
}

/// Reads another process's real menu bar structure via the public
/// Accessibility API. This is read-only inspection — it never mutates the
/// target app's menu, which is what keeps this approach from touching (and
/// risking corrupting) the target app's bundle or in-memory state.
enum MenuBarInspector {
    static func menuBarItems(for pid: pid_t) -> [MenuBarItemInfo] {
        let appElement = AXUIElementCreateApplication(pid)

        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, "AXMenuBar" as CFString, &menuBarRef) == .success,
              let menuBarRaw = menuBarRef else { return [] }
        let menuBar = menuBarRaw as! AXUIElement

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBar, "AXChildren" as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return [] }

        return children.compactMap { element in
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, "AXTitle" as CFString, &titleRef)
            guard let title = titleRef as? String, !title.isEmpty else { return nil }

            var point = CGPoint.zero
            var size = CGSize.zero

            var positionRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &positionRef) == .success,
               let positionValue = positionRef {
                AXValueGetValue(positionValue as! AXValue, .cgPoint, &point)
            }

            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
               let sizeValue = sizeRef {
                AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
            }

            return MenuBarItemInfo(title: title, frame: CGRect(origin: point, size: size))
        }
    }
}

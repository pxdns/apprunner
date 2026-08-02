import AppKit

/// Shared sizing for the notch's states — used both by NotchController
/// (to size the fixed backing window) and NotchContentView (to size the
/// inner shape drawn within that window), so they can never disagree.
enum NotchGeometry {
    /// Sized to the *real* physical notch when one exists (via the public
    /// safeAreaInsets/auxiliaryTopLeftArea+auxiliaryTopRightArea APIs,
    /// available macOS 12+) — matches the camera housing's cutout exactly
    /// on a notched machine like an M2 MacBook Air. Falls back to a fixed
    /// size on displays with no physical notch. Shown when nothing's
    /// playing and the mouse isn't over the notch.
    static func closedSize(for screen: NSScreen) -> NSSize {
        let height = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 26
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return NSSize(width: max(width, 120), height: height)
        }
        return NSSize(width: 200, height: height)
    }

    /// Wider than the physical notch by an equal amount on each side, and
    /// noticeably taller — the compact artwork+visualizer bar. This is the
    /// *resting* size whenever something's playing (no hover needed), and
    /// also what's shown on hover when nothing's playing.
    static func compactSize(for screen: NSScreen, sidePadding: CGFloat) -> NSSize {
        let closed = closedSize(for: screen)
        return NSSize(width: closed.width + sidePadding * 2, height: max(closed.height, 70))
    }

    /// Taller still — the full preview card (title/artist/progress with
    /// time labels/transport controls), shown only while actively
    /// hovering over the notch and something's playing.
    static func previewSize(for screen: NSScreen, sidePadding: CGFloat) -> NSSize {
        let compact = compactSize(for: screen, sidePadding: sidePadding)
        return NSSize(width: compact.width, height: 168)
    }

    static func openSize(width: CGFloat, height: CGFloat) -> NSSize {
        NSSize(width: width, height: height)
    }

    /// The fixed backing-window size: large enough to contain every state,
    /// so the window itself never needs to be resized again after
    /// creation (resizing an NSWindow while the mouse is over it is what
    /// causes hover-tracking flicker).
    @MainActor
    static func maxCanvasSize(for screen: NSScreen, settings: NotchSettingsStore) -> NSSize {
        let padding = CGFloat(settings.hoverSidePadding)
        let closed = closedSize(for: screen)
        let compact = compactSize(for: screen, sidePadding: padding)
        let preview = previewSize(for: screen, sidePadding: padding)
        let open = openSize(width: CGFloat(settings.expandedWidth), height: CGFloat(settings.expandedHeight))
        return NSSize(
            width: max(closed.width, compact.width, preview.width, open.width),
            height: max(closed.height, compact.height, preview.height, open.height)
        )
    }
}

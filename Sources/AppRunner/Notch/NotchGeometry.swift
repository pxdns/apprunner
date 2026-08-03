import AppKit

/// Shared sizing for the notch's states — used both by NotchController
/// (to size the fixed backing window) and NotchContentView (to size the
/// inner shape drawn within that window), so they can never disagree.
enum NotchGeometry {
    /// The exact physical notch footprint (via the public
    /// safeAreaInsets/auxiliaryTopLeftArea+auxiliaryTopRightArea APIs,
    /// available macOS 12+) on a notched machine like an M2 MacBook Air.
    /// Falls back to a fixed size on displays with no physical notch.
    ///
    /// Not used directly for anything visible — content painted at
    /// exactly this size/position doesn't actually render, since that
    /// exact strip is the camera housing's own reserved area. It's the
    /// baseline restingSize grows out from into the always-visible menu
    /// bar area flanking it.
    static func notchFootprint(for screen: NSScreen) -> NSSize {
        let height = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 26
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return NSSize(width: max(width, 120), height: height)
        }
        return NSSize(width: 200, height: height)
    }

    /// The resting state — shown at all times, playing or not. Slightly
    /// wider/taller than the physical notch so part of it always sits in
    /// the definitely-rendered menu bar area on either side, instead of
    /// being confined to the notch's own (not visibly paintable) strip.
    /// Content is a small accent dot when nothing's playing, or a small
    /// artwork thumbnail + waveform icon when something is.
    static func restingSize(for screen: NSScreen) -> NSSize {
        let notch = notchFootprint(for: screen)
        return NSSize(width: notch.width + 28, height: notch.height + 6)
    }

    /// The full preview card (title/artist/progress with time labels/
    /// transport controls), shown only while actively hovering over the
    /// notch and something's playing.
    static func previewSize(for screen: NSScreen, sidePadding: CGFloat) -> NSSize {
        let resting = restingSize(for: screen)
        return NSSize(width: resting.width + sidePadding * 2, height: 168)
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
        let resting = restingSize(for: screen)
        let preview = previewSize(for: screen, sidePadding: padding)
        let open = openSize(width: CGFloat(settings.expandedWidth), height: CGFloat(settings.expandedHeight))
        return NSSize(
            width: max(resting.width, preview.width, open.width),
            height: max(resting.height, preview.height, open.height)
        )
    }
}

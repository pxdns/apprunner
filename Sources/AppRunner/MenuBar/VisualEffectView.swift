import AppKit
import SwiftUI

/// Wraps NSVisualEffectView so overlay patches blend with the system menu
/// bar's translucent material instead of looking like flat rectangles
/// pasted on top.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .titlebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

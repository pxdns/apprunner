import SwiftUI

struct MenuBarOverlayEntry: Identifiable {
    let item: MenuBarItemInfo
    let rule: MenuBarCustomizationStore.Rule
    var id: String { item.title }
}

/// Paints patches over specific menu bar item frames: blank (matching the
/// system material) for hidden items, or custom text for renamed ones.
/// Positioned in the same top-left-origin coordinate space the
/// Accessibility API reports, which lines up with this window's content.
struct MenuBarOverlayView: View {
    let entries: [MenuBarOverlayEntry]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(entries) { entry in
                cell(for: entry)
                    .frame(width: entry.item.frame.width, height: entry.item.frame.height)
                    .position(x: entry.item.frame.midX, y: entry.item.frame.midY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func cell(for entry: MenuBarOverlayEntry) -> some View {
        ZStack {
            VisualEffectView(material: .titlebar)
            if !entry.rule.hidden, let renamed = entry.rule.renamedTo, !renamed.isEmpty {
                Text(renamed)
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
        }
    }
}

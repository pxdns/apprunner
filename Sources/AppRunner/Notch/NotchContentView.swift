import SwiftUI

enum NotchTab: String, CaseIterable {
    case terminal = "Terminal"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .terminal: return "terminal"
        case .settings: return "gearshape"
        }
    }
}

/// The notch's SwiftUI content: nearly invisible when collapsed (sized to
/// match the real physical notch, so it just blends in), expanding
/// downward on hover into a real terminal + a settings tab.
struct NotchContentView: View {
    @ObservedObject var settings: NotchSettingsStore
    @Binding var isExpanded: Bool
    @State private var tab: NotchTab = .terminal

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar

            if isExpanded {
                expandedContent
                    .padding(12)
                    .frame(width: CGFloat(settings.expandedWidth), height: CGFloat(settings.expandedHeight))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: CGFloat(settings.cornerRadius),
                bottomTrailingRadius: CGFloat(settings.cornerRadius),
                topTrailingRadius: 0
            )
            .fill(.black)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpanded = hovering
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    private var collapsedBar: some View {
        HStack {
            Spacer()
            Circle()
                .fill(settings.accentColor)
                .frame(width: 5, height: 5)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 4)
        .padding(.top, 2)
    }

    private var expandedContent: some View {
        VStack(spacing: 10) {
            Picker("", selection: $tab) {
                ForEach(NotchTab.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.symbol).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case .terminal:
                TerminalPaneView(settings: settings)
            case .settings:
                NotchSettingsView(settings: settings)
            }
        }
        .colorScheme(.dark)
    }
}

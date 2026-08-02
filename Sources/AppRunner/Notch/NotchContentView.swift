import SwiftUI

enum NotchTab: String, CaseIterable {
    case terminal = "Terminal"
    case media = "Media"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .terminal: return "terminal"
        case .media: return "music.note"
        case .settings: return "gearshape"
        }
    }
}

/// The notch's SwiftUI content, driving three sizes via `displayState`:
/// - closed: matches the real physical notch, nearly invisible.
/// - hover: mouse is over it but hasn't clicked — a wider bar showing
///   now-playing artwork/progress/visualizer (boring-notch's hover preview).
/// - open: clicked — the full Terminal/Media/Settings tabbed panel.
struct NotchContentView: View {
    @ObservedObject var settings: NotchSettingsStore
    @StateObject private var nowPlaying: NowPlayingModel
    @Binding var displayState: NotchDisplayState
    @State private var isHovering = false
    @State private var isOpen = false
    @State private var tab: NotchTab = .terminal

    init(settings: NotchSettingsStore, displayState: Binding<NotchDisplayState>) {
        self.settings = settings
        self._displayState = displayState
        self._nowPlaying = StateObject(wrappedValue: NowPlayingModel(settings: settings))
    }

    private var localState: NotchDisplayState {
        if isOpen { return .open }
        return isHovering ? .hover : .closed
    }

    var body: some View {
        Group {
            switch localState {
            case .closed:
                closedBar
            case .hover:
                NotchHoverBar(nowPlaying: nowPlaying)
            case .open:
                openPanel
                    .padding(12)
                    .frame(width: CGFloat(settings.expandedWidth), height: CGFloat(settings.expandedHeight))
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
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovering = hovering
                if !hovering { isOpen = false }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) { isOpen = true }
        }
        .onChange(of: localState) { _, newValue in
            displayState = newValue
        }
        .onAppear {
            nowPlaying.start()
        }
    }

    private var closedBar: some View {
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

    private var openPanel: some View {
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
            case .media:
                NowPlayingFullView(nowPlaying: nowPlaying)
            case .settings:
                NotchSettingsView(settings: settings)
            }
        }
        .colorScheme(.dark)
    }
}

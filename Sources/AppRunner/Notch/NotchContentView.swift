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

/// Renders inside a fixed-size backing window (see NotchController): only
/// the *inner* shape's width/height change between closed → hover → open,
/// animated by SwiftUI, top-anchored so it always grows down/out from the
/// real notch position rather than the window itself ever moving or resizing.
struct NotchContentView: View {
    @ObservedObject var settings: NotchSettingsStore
    @StateObject private var nowPlaying: NowPlayingModel
    @State private var isHovering = false
    @State private var isOpen = false
    @State private var tab: NotchTab = .terminal

    init(settings: NotchSettingsStore) {
        self.settings = settings
        self._nowPlaying = StateObject(wrappedValue: NowPlayingModel(settings: settings))
    }

    private var localState: NotchDisplayState {
        if isOpen { return .open }
        return isHovering ? .hover : .closed
    }

    private var screen: NSScreen { NSScreen.main ?? NSScreen.screens.first! }

    private var currentSize: NSSize {
        switch localState {
        case .closed:
            return NotchGeometry.closedSize(for: screen)
        case .hover:
            return NotchGeometry.hoverSize(for: screen, sidePadding: CGFloat(settings.hoverSidePadding))
        case .open:
            return NotchGeometry.openSize(width: CGFloat(settings.expandedWidth), height: CGFloat(settings.expandedHeight))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            pill
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            nowPlaying.start()
        }
    }

    private var pill: some View {
        Group {
            switch localState {
            case .closed:
                closedBar
            case .hover:
                NotchHoverBar(nowPlaying: nowPlaying)
            case .open:
                openPanel.padding(12)
            }
        }
        .frame(width: currentSize.width, height: currentSize.height)
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
    }

    /// A thin accent-colored strip along the bottom edge of the closed
    /// pill — much easier to actually spot than a tiny centered dot, since
    /// it sits right where the physical notch's black housing ends and
    /// normal wallpaper/menu bar begins.
    private var closedBar: some View {
        VStack {
            Spacer(minLength: 0)
            Capsule()
                .fill(settings.accentColor.opacity(0.85))
                .frame(width: 56, height: 3)
                .padding(.bottom, 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

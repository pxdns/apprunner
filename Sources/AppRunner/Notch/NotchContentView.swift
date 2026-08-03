import SwiftUI

enum NotchTab: String, CaseIterable, Equatable {
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

/// Renders inside a fixed-size backing window (see NotchController). State
/// ladder:
/// - resting: always shown otherwise — a small accent dot (nothing
///   playing) or artwork thumbnail + waveform icon (something is), sized
///   just slightly beyond the physical notch so it's actually visible
///   (content painted at the notch's own exact size/position doesn't
///   render at all — that strip is reserved for the camera housing).
/// - preview: hovering while something's playing — the full card with
///   progress/time labels/transport controls.
/// - open: single-click — the full Terminal/Media/Settings tabbed panel.
///   Double-clicking is explicitly a no-op.
struct NotchContentView: View {
    @ObservedObject var settings: NotchSettingsStore
    @ObservedObject var navigator: NotchNavigator
    @StateObject private var nowPlaying: NowPlayingModel
    @State private var isHovering = false
    @State private var isOpen = false
    @State private var tab: NotchTab = .terminal

    init(settings: NotchSettingsStore, navigator: NotchNavigator) {
        self.settings = settings
        self.navigator = navigator
        self._nowPlaying = StateObject(wrappedValue: NowPlayingModel(settings: settings))
    }

    private var hasNowPlaying: Bool { !nowPlaying.info.title.isEmpty }

    private var localState: NotchDisplayState {
        if isOpen { return .open }
        if isHovering && hasNowPlaying { return .preview }
        return .resting
    }

    private var screen: NSScreen { NSScreen.main ?? NSScreen.screens.first! }

    private var currentSize: NSSize {
        switch localState {
        case .resting:
            return NotchGeometry.restingSize(for: screen)
        case .preview:
            return NotchGeometry.previewSize(for: screen, sidePadding: CGFloat(settings.hoverSidePadding))
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
        .onChange(of: navigator.requestedTab) { _, requested in
            guard let requested else { return }
            tab = requested
            withAnimation(.easeInOut(duration: 0.18)) { isOpen = true }
            navigator.requestedTab = nil
        }
    }

    private var pill: some View {
        Group {
            switch localState {
            case .resting:
                hasNowPlaying ? AnyView(NotchHoverBar(nowPlaying: nowPlaying)) : AnyView(restingDot)
            case .preview:
                NotchPreviewCard(nowPlaying: nowPlaying)
                    .colorScheme(.dark)
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
        // Double-click is an explicit no-op — attaching it alongside the
        // single-tap gesture makes SwiftUI resolve them exclusively (a
        // double-click never also fires the single-click handler).
        .onTapGesture(count: 2) {}
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.18)) { isOpen = true }
        }
    }

    /// Resting-and-nothing-playing content: a thin accent-colored strip
    /// along the bottom edge — easier to spot than a tiny centered dot.
    private var restingDot: some View {
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

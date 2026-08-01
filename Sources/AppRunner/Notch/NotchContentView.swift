import SwiftUI

enum NotchTab: String, CaseIterable {
    case launcher = "Apps"
    case terminal = "Terminal"
    case nowPlaying = "Media"
    case menuBar = "Menu"

    var symbol: String {
        switch self {
        case .launcher: return "square.grid.2x2"
        case .terminal: return "terminal"
        case .nowPlaying: return "music.note"
        case .menuBar: return "menubar.rectangle"
        }
    }
}

/// The notch's SwiftUI content: a slim black pill when collapsed, expanding
/// downward into the launcher/terminal/media panel on hover — mirroring the
/// boring-notch interaction model but scoped to app launching + a shell.
struct NotchContentView: View {
    @ObservedObject var appLibrary: AppLibrary
    @ObservedObject var menuBarStore: MenuBarCustomizationStore
    @StateObject private var systemMonitor = SystemMonitor()
    @StateObject private var nowPlaying = NowPlayingModel()
    @Binding var isExpanded: Bool
    @State private var tab: NotchTab = .launcher

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar

            if isExpanded {
                expandedContent
                    .padding(12)
                    .frame(width: 320)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
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
        .onAppear {
            systemMonitor.start()
            nowPlaying.start()
        }
    }

    private var collapsedBar: some View {
        HStack(spacing: 6) {
            if nowPlaying.info.title.isEmpty {
                defaultCollapsedContent
            } else {
                nowPlayingCollapsedContent
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
    }

    private var defaultCollapsedContent: some View {
        HStack(spacing: 6) {
            Circle().fill(.green).frame(width: 6, height: 6)
            Text("AppRunner")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            if !appLibrary.running.isEmpty {
                Text("\(appLibrary.running.count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.green, in: Capsule())
            }
            Spacer(minLength: 6)
            statStrip
        }
    }

    /// Album art on one side, a little live audio visualizer on the other —
    /// mirrors boring-notch's idle "something's playing" look, right in the
    /// collapsed pill instead of only inside the Media tab.
    private var nowPlayingCollapsedContent: some View {
        HStack {
            artworkThumbnail
            Spacer(minLength: 8)
            Image(systemName: "waveform")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.9))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: nowPlaying.info.isPlaying)
        }
    }

    private var artworkThumbnail: some View {
        Group {
            if let artwork = nowPlaying.info.artwork {
                Image(nsImage: artwork).resizable()
            } else {
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.15))
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var statStrip: some View {
        HStack(spacing: 8) {
            Label("\(Int(systemMonitor.cpuUsage))%", systemImage: "cpu")
            Label("\(Int(systemMonitor.memoryUsedFraction * 100))%", systemImage: "memorychip")
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.white.opacity(0.7))
        .labelStyle(.titleAndIcon)
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
            case .launcher:
                LauncherView(appLibrary: appLibrary)
            case .terminal:
                TerminalView()
            case .nowPlaying:
                NowPlayingView()
            case .menuBar:
                MenuBarEditorView(store: menuBarStore)
            }
        }
        .colorScheme(.dark)
    }
}

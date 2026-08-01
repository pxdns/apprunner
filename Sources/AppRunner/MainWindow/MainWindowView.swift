import SwiftUI

/// A normal, always-discoverable window that shows everything the notch
/// does (Apps/Terminal/Media/Menu) plus Settings, in one resizable window
/// with a visible titlebar. The notch is a nice-to-have quick-access
/// shortcut on top of this — this window is the "yes, the app is actually
/// running, here's the UI" anchor.
struct MainWindowView: View {
    @ObservedObject var appLibrary: AppLibrary
    @ObservedObject var menuBarStore: MenuBarCustomizationStore
    @State private var tab: NotchTab = .launcher
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(NotchTab.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.symbol).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 14)

            Divider().padding(.top, 10)

            ScrollView {
                content
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .colorScheme(.dark)
            .background(Color.black.opacity(0.92))

            Divider()

            HStack {
                Text("AppRunner is running — look for its icon in the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Settings…") { showSettings = true }
            }
            .padding(10)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 480, idealHeight: 520)
        .sheet(isPresented: $showSettings) {
            PreferencesView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showSettings = false }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
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
}

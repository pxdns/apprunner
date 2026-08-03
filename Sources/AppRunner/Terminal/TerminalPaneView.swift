import SwiftUI

/// The Terminal tab's SwiftUI content: a real terminal (see
/// TerminalHostView) plus a theme picker. Named "Pane" rather than
/// "TerminalView" to avoid colliding with SwiftTerm's own `TerminalView`
/// AppKit class, which is imported into this module.
struct TerminalPaneView: View {
    @ObservedObject var settings: NotchSettingsStore

    var body: some View {
        VStack(spacing: 6) {
            TerminalHostView(theme: settings.terminalTheme)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text("Theme").font(.system(size: 10)).foregroundStyle(.secondary)
                Picker("", selection: $settings.terminalThemeID) {
                    ForEach(TerminalTheme.all) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
                Spacer()
            }
        }
    }
}

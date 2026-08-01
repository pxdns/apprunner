import SwiftUI

struct PreferencesView: View {
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AppRunner Preferences")
                .font(.headline)

            Toggle("Launch AppRunner at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    LoginItemManager.setEnabled(launchAtLogin)
                }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Global shortcut").font(.subheadline).bold()
                Text("⌥ Space — show or hide the notch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tips").font(.subheadline).bold()
                Text("Right-click an app in the launcher to pin it or create a renamed shortcut.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

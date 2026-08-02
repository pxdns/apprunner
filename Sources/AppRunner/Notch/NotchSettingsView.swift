import SwiftUI

struct NotchSettingsView: View {
    @ObservedObject var settings: NotchSettingsStore

    private let accentOptions: [UInt32] = [0x0A84FF, 0xFF375F, 0x30D158, 0xFFD60A, 0xBF5AF2, 0xFF9F0A]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Notch Settings")
                    .font(.system(size: 12, weight: .semibold))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Accent color").font(.system(size: 10)).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(accentOptions, id: \.self) { hex in
                            swatch(hex)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Corner radius: \(Int(settings.cornerRadius))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Slider(value: $settings.cornerRadius, in: 0...28)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hover bar width (each side): \(Int(settings.hoverSidePadding))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Slider(value: $settings.hoverSidePadding, in: 40...200)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Expanded width: \(Int(settings.expandedWidth))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Slider(value: $settings.expandedWidth, in: 320...700)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Expanded height: \(Int(settings.expandedHeight))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Slider(value: $settings.expandedHeight, in: 220...560)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Now Playing source").font(.system(size: 10)).foregroundStyle(.secondary)
                    Picker("", selection: sourceBinding) {
                        ForEach(NowPlayingSource.curated) { source in
                            Text(source.name).tag(source.id ?? "")
                        }
                        Text("Custom bundle ID…").tag("__custom__")
                    }
                    .labelsHidden()

                    if isCustomSelected {
                        TextField("com.example.App", text: $settings.customSourceBundleID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                            .onChange(of: settings.customSourceBundleID) {
                                settings.preferredNowPlayingSourceID = settings.customSourceBundleID
                            }
                    }

                    Text("Only shows Now Playing when this app is the source; \"Automatic\" shows whatever macOS reports.")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
    }

    private var isCustomSelected: Bool {
        guard let id = settings.preferredNowPlayingSourceID else { return false }
        return !NowPlayingSource.curated.contains { $0.id == id }
    }

    private var sourceBinding: Binding<String> {
        Binding<String>(
            get: {
                if isCustomSelected { return "__custom__" }
                return settings.preferredNowPlayingSourceID ?? ""
            },
            set: { newValue in
                if newValue == "__custom__" {
                    settings.preferredNowPlayingSourceID = settings.customSourceBundleID.isEmpty ? "__custom__" : settings.customSourceBundleID
                } else {
                    settings.preferredNowPlayingSourceID = newValue.isEmpty ? nil : newValue
                }
            }
        )
    }

    private func swatch(_ hex: UInt32) -> some View {
        Circle()
            .fill(Color(nsColor: NSColor(hex: hex)))
            .frame(width: 20, height: 20)
            .overlay(
                Circle().stroke(.white, lineWidth: settings.accentHex == hex ? 2 : 0)
            )
            .onTapGesture { settings.accentHex = hex }
    }
}

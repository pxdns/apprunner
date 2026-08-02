import SwiftUI

struct NotchSettingsView: View {
    @ObservedObject var settings: NotchSettingsStore

    private let accentOptions: [UInt32] = [0x0A84FF, 0xFF375F, 0x30D158, 0xFFD60A, 0xBF5AF2, 0xFF9F0A]

    var body: some View {
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
                Text("Expanded width: \(Int(settings.expandedWidth))")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Slider(value: $settings.expandedWidth, in: 320...700)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Expanded height: \(Int(settings.expandedHeight))")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Slider(value: $settings.expandedHeight, in: 220...560)
            }
        }
        .padding(12)
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

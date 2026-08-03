import SwiftUI

/// The compact *resting* state: a small artwork thumbnail and a tiny
/// waveform icon, sized to fit entirely within the physical notch's own
/// footprint — no progress track, no growth. This is what shows whenever
/// something's playing, without needing to hover; the bigger card with
/// progress/time/controls (NotchPreviewCard) only appears on actual hover.
struct NotchHoverBar: View {
    @ObservedObject var nowPlaying: NowPlayingModel

    var body: some View {
        HStack(spacing: 6) {
            artwork
            Spacer(minLength: 2)
            if !nowPlaying.info.title.isEmpty {
                Image(systemName: "waveform")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.9))
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: nowPlaying.info.isPlaying)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var artwork: some View {
        Group {
            if let art = nowPlaying.info.artwork {
                Image(nsImage: art).resizable()
            } else {
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.12))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxHeight: .infinity)
        .padding(.vertical, 4)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

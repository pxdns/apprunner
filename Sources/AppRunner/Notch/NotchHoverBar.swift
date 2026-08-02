import SwiftUI

/// The mid-size "hovering, not yet clicked" state: artwork on the left, a
/// playback progress track in the middle, a little audio visualizer icon
/// on the right — matching boring-notch's hover preview. Shown only while
/// the mouse is over the notch and it hasn't been clicked open yet.
struct NotchHoverBar: View {
    @ObservedObject var nowPlaying: NowPlayingModel

    var body: some View {
        HStack(spacing: 14) {
            artwork

            if nowPlaying.info.title.isEmpty {
                Text("No now-playing source")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            } else {
                progressTrack
            }

            Image(systemName: "waveform")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: nowPlaying.info.isPlaying)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var artwork: some View {
        Group {
            if let art = nowPlaying.info.artwork {
                Image(nsImage: art).resizable()
            } else {
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.12))
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var progressTrack: some View {
        let fraction: Double = nowPlaying.info.duration > 0 ? nowPlaying.info.elapsed / nowPlaying.info.duration : 0
        let clamped = CGFloat(max(0, min(1, fraction)))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(.white.opacity(0.85))
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: 4)
    }
}

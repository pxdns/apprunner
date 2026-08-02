import SwiftUI

/// The full hover preview: bigger artwork, title/artist, a progress track
/// with elapsed/remaining time labels, and transport controls — shown only
/// while actively hovering over the notch while something's playing.
struct NotchPreviewCard: View {
    @ObservedObject var nowPlaying: NowPlayingModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                artwork
                VStack(alignment: .leading, spacing: 3) {
                    Text(nowPlaying.info.title)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                    Text(nowPlaying.info.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 4) {
                progressTrack
                HStack {
                    Text(formatted(nowPlaying.info.elapsed))
                    Spacer()
                    Text(formatted(nowPlaying.info.duration))
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 26) {
                Button { MediaRemoteBridge.shared.send(.previousTrack) } label: {
                    Image(systemName: "backward.fill")
                }
                Button { MediaRemoteBridge.shared.send(.togglePlayPause) } label: {
                    Image(systemName: nowPlaying.info.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17))
                }
                Button { MediaRemoteBridge.shared.send(.nextTrack) } label: {
                    Image(systemName: "forward.fill")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(16)
    }

    private var artwork: some View {
        Group {
            if let art = nowPlaying.info.artwork {
                Image(nsImage: art).resizable()
            } else {
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.12))
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var progressTrack: some View {
        let fraction: Double = nowPlaying.info.duration > 0 ? nowPlaying.info.elapsed / nowPlaying.info.duration : 0
        let clamped = CGFloat(max(0, min(1, fraction)))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(.white.opacity(0.9))
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: 4)
    }

    private func formatted(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

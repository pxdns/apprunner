import SwiftUI

/// Full now-playing controls shown in the open panel's Media tab —
/// artwork, title/artist, and play/pause/skip.
struct NowPlayingFullView: View {
    @ObservedObject var nowPlaying: NowPlayingModel

    var body: some View {
        VStack(spacing: 12) {
            if nowPlaying.info.title.isEmpty {
                Text("Nothing playing")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                HStack(spacing: 10) {
                    artworkView
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nowPlaying.info.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(nowPlaying.info.artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                HStack(spacing: 22) {
                    Button { MediaRemoteBridge.shared.send(.previousTrack) } label: {
                        Image(systemName: "backward.fill")
                    }
                    Button { MediaRemoteBridge.shared.send(.togglePlayPause) } label: {
                        Image(systemName: nowPlaying.info.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                    }
                    Button { MediaRemoteBridge.shared.send(.nextTrack) } label: {
                        Image(systemName: "forward.fill")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 4)
    }

    private var artworkView: some View {
        Group {
            if let artwork = nowPlaying.info.artwork {
                Image(nsImage: artwork).resizable()
            } else {
                RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.15))
                    .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

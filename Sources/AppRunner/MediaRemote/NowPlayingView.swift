import AppKit
import SwiftUI

struct NowPlayingView: View {
    @StateObject private var model = NowPlayingModel()

    var body: some View {
        VStack(spacing: 12) {
            if model.info.title.isEmpty {
                Text("Nothing playing")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                HStack(spacing: 10) {
                    artworkView
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.info.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(model.info.artist)
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
                        Image(systemName: model.info.isPlaying ? "pause.fill" : "play.fill")
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
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var artworkView: some View {
        Group {
            if let artwork = model.info.artwork {
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

@MainActor
final class NowPlayingModel: ObservableObject {
    @Published var info = NowPlayingInfo()
    private var subscriptionID: UUID?

    func start() {
        guard subscriptionID == nil else { return }
        subscriptionID = MediaRemoteBridge.shared.subscribe { [weak self] info in
            self?.info = info
        }
        MediaRemoteBridge.shared.startPolling()
    }

    func stop() {
        if let subscriptionID {
            MediaRemoteBridge.shared.unsubscribe(subscriptionID)
        }
        subscriptionID = nil
        MediaRemoteBridge.shared.stopPolling()
    }
}

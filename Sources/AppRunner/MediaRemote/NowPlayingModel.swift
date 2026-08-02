import Foundation

/// Wraps MediaRemoteBridge for SwiftUI, applying the "preferred source"
/// filter from settings: if you've picked a specific app, updates from any
/// other app are treated as "nothing playing" rather than shown.
@MainActor
final class NowPlayingModel: ObservableObject {
    @Published var info = NowPlayingInfo()

    private var subscriptionID: UUID?
    private weak var settings: NotchSettingsStore?

    init(settings: NotchSettingsStore) {
        self.settings = settings
    }

    func start() {
        guard subscriptionID == nil else { return }
        subscriptionID = MediaRemoteBridge.shared.subscribe { [weak self] info in
            self?.apply(info)
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

    private func apply(_ newInfo: NowPlayingInfo) {
        guard let preferred = settings?.preferredNowPlayingSourceID, !preferred.isEmpty else {
            info = newInfo
            return
        }
        if newInfo.sourceBundleID == preferred {
            info = newInfo
        } else {
            info = NowPlayingInfo() // preferred source isn't the one currently playing
        }
    }
}

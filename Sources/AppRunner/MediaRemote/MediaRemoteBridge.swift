import AppKit
import Foundation

/// Bridges Apple's private MediaRemote.framework, loaded at runtime via
/// dlopen/dlsym (never linked, no header available) — the same technique
/// boring-notch-style menu-bar apps use, since there is no public API for
/// system-wide now-playing info. Because the framework is private, symbol
/// lookups fail gracefully (nil) rather than crashing on OS versions where
/// the ABI shifts.
///
/// Caveat worth knowing: starting around macOS 15.4, Apple tightened what
/// third-party (non-Music/non-entitled) processes can get back from
/// MRMediaRemoteGetNowPlayingInfo — real boring-notch had to add a whole
/// separate helper-process workaround for it. This bridge will still try,
/// and fails silently (empty state, not a crash) if your macOS version
/// blocks it — there's no clean way to detect that in advance.
enum MediaRemoteCommand: UInt32 {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

struct NowPlayingInfo {
    var title: String = ""
    var artist: String = ""
    var artwork: NSImage?
    var isPlaying: Bool = false
    var elapsed: Double = 0
    var duration: Double = 0
    /// Bundle identifier of the app currently reporting now-playing info,
    /// when we could resolve one — used for the "preferred source" filter.
    var sourceBundleID: String?
}

final class MediaRemoteBridge: NSObject {
    static let shared = MediaRemoteBridge()

    private typealias GetNowPlayingInfoFn = @convention(c) (DispatchQueue, @convention(block) @escaping ([String: Any]) -> Void) -> Void
    private typealias GetNowPlayingPIDFn = @convention(c) (DispatchQueue, @convention(block) @escaping (Int32) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (UInt32, AnyObject?) -> Bool
    private typealias RegisterNotificationsFn = @convention(c) (DispatchQueue) -> Void

    private var getNowPlayingInfo: GetNowPlayingInfoFn?
    private var getNowPlayingPID: GetNowPlayingPIDFn?
    private var sendCommand: SendCommandFn?

    // Multiple views observe now-playing at once (the notch hover bar
    // *and* the full Media tab) — fan out to all subscribers and
    // reference-count polling instead of one view's stop() killing
    // another's feed.
    private var subscribers: [UUID: (NowPlayingInfo) -> Void] = [:]
    private var pollTimer: Timer?
    private var pollRefCount = 0

    private override init() {
        super.init()
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        ) else { return }

        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfo = unsafeBitCast(sym, to: GetNowPlayingInfoFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
            getNowPlayingPID = unsafeBitCast(sym, to: GetNowPlayingPIDFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(sym, to: SendCommandFn.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let registerFn = unsafeBitCast(sym, to: RegisterNotificationsFn.self)
            registerFn(.main)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNowPlayingChange),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil
        )
    }

    var isAvailable: Bool { getNowPlayingInfo != nil }

    @discardableResult
    func subscribe(_ handler: @escaping (NowPlayingInfo) -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = handler
        return id
    }

    func unsubscribe(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    func startPolling(interval: TimeInterval = 2) {
        pollRefCount += 1
        refresh()
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopPolling() {
        pollRefCount = max(0, pollRefCount - 1)
        guard pollRefCount == 0 else { return }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc private func handleNowPlayingChange() {
        refresh()
    }

    func refresh() {
        guard let getNowPlayingInfo else { return }
        getNowPlayingInfo(.main) { [weak self] info in
            guard let self else { return }
            var result = NowPlayingInfo()
            result.title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            result.artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            if let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double {
                result.isPlaying = rate > 0
            }
            if let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double {
                result.elapsed = elapsed
            }
            if let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double {
                result.duration = duration
            }
            if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                result.artwork = NSImage(data: artworkData)
            }

            self.resolveSourceBundleID { bundleID in
                result.sourceBundleID = bundleID
                DispatchQueue.main.async {
                    for handler in self.subscribers.values {
                        handler(result)
                    }
                }
            }
        }
    }

    private func resolveSourceBundleID(_ completion: @escaping (String?) -> Void) {
        guard let getNowPlayingPID else {
            completion(nil)
            return
        }
        getNowPlayingPID(.main) { pid in
            guard pid > 0 else {
                completion(nil)
                return
            }
            completion(NSRunningApplication(processIdentifier: pid)?.bundleIdentifier)
        }
    }

    func send(_ command: MediaRemoteCommand) {
        _ = sendCommand?(command.rawValue, nil)
    }
}

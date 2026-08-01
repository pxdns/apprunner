import AppKit
import Foundation

/// Bridges Apple's private MediaRemote.framework, loaded at runtime via
/// dlopen/dlsym (never linked, no header available). This is the same
/// technique the well-known "boring notch" style menu-bar apps use to show
/// system-wide now-playing info — there is no public API for it. Because
/// the framework is private, symbol lookups fail gracefully (nil) rather
/// than crashing on OS versions where the ABI shifts.
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
}

final class MediaRemoteBridge: NSObject {
    static let shared = MediaRemoteBridge()

    private typealias GetNowPlayingInfoFn = @convention(c) (DispatchQueue, @convention(block) @escaping ([String: Any]) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (UInt32, AnyObject?) -> Bool
    private typealias RegisterNotificationsFn = @convention(c) (DispatchQueue) -> Void

    private var getNowPlayingInfo: GetNowPlayingInfoFn?
    private var sendCommand: SendCommandFn?

    // Multiple views observe now-playing at once (the collapsed notch pill
    // *and* the Media tab, potentially in more than one window) — a single
    // callback slot would let the latest subscriber silently steal updates
    // from earlier ones, so this fans out to all of them and reference-
    // counts polling instead of one view's stop() killing another's feed.
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

    func startPolling(interval: TimeInterval = 3) {
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
            if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                result.artwork = NSImage(data: artworkData)
            }
            DispatchQueue.main.async {
                for handler in self.subscribers.values {
                    handler(result)
                }
            }
        }
    }

    func send(_ command: MediaRemoteCommand) {
        _ = sendCommand?(command.rawValue, nil)
    }
}

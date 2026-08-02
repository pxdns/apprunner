import AppKit
import Foundation

/// Two ways of getting system-wide now-playing info, tried in order:
///
/// 1. **mediaremote-adapter** (MediaRemoteAdapterProcess) — the real fix
///    for macOS 15.4+/Tahoe, where Apple added entitlement verification
///    that blocks a plain third-party dlopen of MediaRemote.framework.
///    Works by running `/usr/bin/perl` (a system binary that does carry
///    the entitlement) with a bundled helper framework. Used when present
///    (staged into the app bundle by Scripts/build-mediaremote-adapter.sh).
/// 2. **Direct dlopen/dlsym** of MediaRemote.framework — the original
///    approach, which still works fine on older macOS versions and is
///    used as a fallback if the adapter isn't bundled or fails to launch.
///
/// Playback commands (play/pause/skip) still go through the direct
/// dlsym'd MRMediaRemoteSendCommand either way — the adapter project only
/// covers reading now-playing info, not sending commands.
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

    private let adapter = MediaRemoteAdapterProcess()
    private var usingAdapter = false

    // Multiple views observe now-playing at once (the notch hover bar
    // *and* the full Media tab) — fan out to all subscribers and
    // reference-count start/stop instead of one view's stop() killing
    // another's feed.
    private var subscribers: [UUID: (NowPlayingInfo) -> Void] = [:]
    private var pollTimer: Timer?
    private var isRunning = false
    private var pollRefCount = 0

    private override init() {
        super.init()
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        ) else {
            NSLog("AppRunner: MediaRemote dlopen failed — framework not found at expected path")
            return
        }
        NSLog("AppRunner: MediaRemote dlopen succeeded, macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

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

    var isAvailable: Bool { getNowPlayingInfo != nil || usingAdapter }

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
        guard !isRunning else { return }
        isRunning = true

        adapter.onUpdate = { [weak self] payload in
            self?.handleAdapterPayload(payload)
        }
        if adapter.start() {
            usingAdapter = true
            NSLog("AppRunner: using mediaremote-adapter for Now Playing (works on macOS 15.4+/Tahoe)")
            return
        }

        NSLog("AppRunner: mediaremote-adapter not available, falling back to direct MediaRemote calls")
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopPolling() {
        pollRefCount = max(0, pollRefCount - 1)
        guard pollRefCount == 0, isRunning else { return }
        isRunning = false
        if usingAdapter {
            adapter.stop()
            usingAdapter = false
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func handleAdapterPayload(_ payload: [String: Any]) {
        var result = NowPlayingInfo()
        result.title = payload["title"] as? String ?? ""
        result.artist = payload["artist"] as? String ?? ""
        result.isPlaying = payload["playing"] as? Bool ?? false
        result.elapsed = payload["elapsedTime"] as? Double ?? 0
        result.duration = payload["duration"] as? Double ?? 0
        result.sourceBundleID = (payload["parentApplicationBundleIdentifier"] as? String)
            ?? (payload["bundleIdentifier"] as? String)
        if let base64 = payload["artworkData"] as? String, let data = Data(base64Encoded: base64) {
            result.artwork = NSImage(data: data)
        }
        publish(result)
    }

    @objc private func handleNowPlayingChange() {
        guard !usingAdapter else { return }
        refresh()
    }

    /// Direct dlopen/dlsym fallback path — only used when mediaremote-adapter
    /// isn't bundled or failed to launch.
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

            // Publish immediately — don't let source-app resolution (a
            // second, flakier private call) hold up showing what's
            // actually playing. If/when it resolves, publish again with
            // sourceBundleID filled in.
            DispatchQueue.main.async {
                self.publish(result)
            }
            self.resolveSourceBundleID { bundleID in
                guard let bundleID else { return }
                var withSource = result
                withSource.sourceBundleID = bundleID
                DispatchQueue.main.async {
                    self.publish(withSource)
                }
            }
        }
    }

    private func publish(_ info: NowPlayingInfo) {
        for handler in subscribers.values {
            handler(info)
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

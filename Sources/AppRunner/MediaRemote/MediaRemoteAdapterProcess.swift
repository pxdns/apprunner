import Foundation

/// Spawns the bundled mediaremote-adapter helper (staged into
/// `AppRunner.app/Contents/Resources/MediaRemoteAdapter/` by
/// Scripts/build-mediaremote-adapter.sh) and streams its JSON output.
///
/// Why this exists: Apple added entitlement verification to the
/// MediaRemote daemon around macOS 15.4, so a plain third-party dlopen of
/// MediaRemote.framework (see MediaRemoteBridge's fallback) stops getting
/// real data back. mediaremote-adapter works around this by running
/// `/usr/bin/perl` — a system binary that *does* carry the required
/// entitlement — loading a small helper framework into it, and printing
/// now-playing updates as one JSON object per line. See
/// https://github.com/ungive/mediaremote-adapter.
final class MediaRemoteAdapterProcess {
    private var process: Process?
    private var buffer = Data()
    /// The stream sends diffs, not full snapshots each time — merge
    /// incoming keys into what we already know so unrelated fields (e.g.
    /// artwork, only sent once) aren't lost on the next update.
    private var lastPayload: [String: Any] = [:]

    var onUpdate: (([String: Any]) -> Void)?

    /// - Returns: true if the helper process was found and launched.
    ///   False means the caller should fall back to another approach —
    ///   this doesn't throw since "helper not bundled" is an expected,
    ///   non-error case (e.g. a `swift run` build without Scripts/bundle.sh).
    @discardableResult
    func start() -> Bool {
        guard process == nil else { return true }
        guard let resourceURL = Bundle.main.resourceURL else { return false }

        let adapterDir = resourceURL.appendingPathComponent("MediaRemoteAdapter")
        let script = adapterDir.appendingPathComponent("mediaremote-adapter.pl")
        let framework = adapterDir.appendingPathComponent("MediaRemoteAdapter.framework")
        let fm = FileManager.default
        guard fm.fileExists(atPath: script.path), fm.fileExists(atPath: framework.path) else {
            return false
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script.path, framework.path, "stream"]

        let stdoutPipe = Pipe()
        task.standardOutput = stdoutPipe

        // Per upstream docs, stderr lines are non-fatal warnings — still
        // need to actively drain it though, or a chatty child process can
        // fill the pipe's OS buffer and block on write indefinitely.
        let stderrPipe = Pipe()
        task.standardError = stderrPipe
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consume(data)
        }

        do {
            try task.run()
            process = task
            return true
        } catch {
            NSLog("AppRunner: failed to launch mediaremote-adapter — \(error.localizedDescription)")
            return false
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        buffer.removeAll()
        lastPayload.removeAll()
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        let newline = UInt8(ascii: "\n")
        while let index = buffer.firstIndex(of: newline) {
            let lineData = buffer[buffer.startIndex..<index]
            buffer.removeSubrange(buffer.startIndex...index)
            guard !lineData.isEmpty else { continue }
            handleLine(Data(lineData))
        }
    }

    private func handleLine(_ lineData: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              json["type"] as? String == "data",
              let payload = json["payload"] as? [String: Any]
        else { return }

        for (key, value) in payload {
            lastPayload[key] = value
        }
        let snapshot = lastPayload
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(snapshot)
        }
    }
}

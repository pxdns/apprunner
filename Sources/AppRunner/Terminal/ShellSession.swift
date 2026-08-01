import Foundation
import Darwin

/// Drives an interactive login shell through a real pseudo-terminal so
/// full-screen and line-editing programs behave, while streaming raw output
/// back a line at a time for the (intentionally simple) TerminalView.
final class ShellSession: ObservableObject {
    @Published var output: String = ""

    private var process: Process?
    private var primaryFD: Int32 = -1
    private var readSource: DispatchSourceRead?

    func start() {
        guard process == nil else { return }

        var primary: Int32 = 0
        var replica: Int32 = 0
        var winSize = winsize(ws_row: 32, ws_col: 100, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&primary, &replica, nil, nil, &winSize) == 0 else {
            output += "AppRunner: failed to allocate a pseudo-terminal.\n"
            return
        }
        primaryFD = primary

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: shell)
        task.arguments = ["-il"]

        let replicaHandle = FileHandle(fileDescriptor: replica, closeOnDealloc: true)
        task.standardInput = replicaHandle
        task.standardOutput = replicaHandle
        task.standardError = replicaHandle

        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.output += "\n[process exited]\n"
                self?.stop()
            }
        }

        do {
            try task.run()
            process = task
            beginReading()
        } catch {
            output += "AppRunner: failed to start shell — \(error.localizedDescription)\n"
            close(replica)
            close(primary)
        }
    }

    private func beginReading() {
        let source = DispatchSource.makeReadSource(fileDescriptor: primaryFD, queue: .global(qos: .userInitiated))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = read(self.primaryFD, &buffer, buffer.count)
            guard count > 0 else { return }
            let chunk = String(decoding: buffer[0..<count], as: UTF8.self)
            DispatchQueue.main.async {
                self.output += chunk
            }
        }
        source.resume()
        readSource = source
    }

    func send(_ text: String) {
        guard primaryFD >= 0 else { return }
        let line = text + "\n"
        _ = line.withCString { ptr in
            write(primaryFD, ptr, strlen(ptr))
        }
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
        if primaryFD >= 0 {
            close(primaryFD)
            primaryFD = -1
        }
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
    }
}

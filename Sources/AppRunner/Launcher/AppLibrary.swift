import AppKit
import Combine
import Foundation

/// A launchable application discovered on disk.
struct LaunchableApp: Identifiable, Hashable {
    let id: String            // bundle identifier, falls back to path
    let name: String
    let url: URL
    let icon: NSImage

    static func == (lhs: LaunchableApp, rhs: LaunchableApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Scans the usual application directories and keeps track of which apps
/// AppRunner has launched, so the notch can show a compact "running" strip
/// instead of relaunching (and duplicating) processes — the whole point of
/// running things "inside the launcher" rather than spawning Dock icons.
@MainActor
final class AppLibrary: ObservableObject {
    @Published private(set) var apps: [LaunchableApp] = []
    @Published private(set) var running: [pid_t: LaunchableApp] = [:]
    @Published private(set) var pinnedIDs: Set<String>

    private let searchPaths = [
        "/Applications",
        "/System/Applications",
        (NSHomeDirectory() as NSString).appendingPathComponent("Applications"),
        AppShortcutBuilder.shortcutsDirectory.path
    ]

    private let pinnedDefaultsKey = "AppRunner.pinnedAppIDs"

    init() {
        pinnedIDs = Set(UserDefaults.standard.stringArray(forKey: pinnedDefaultsKey) ?? [])
    }

    func refresh() {
        let fm = FileManager.default
        var found: [LaunchableApp] = []
        for base in searchPaths {
            guard let entries = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let path = (base as NSString).appendingPathComponent(entry)
                let url = URL(fileURLWithPath: path)
                guard let bundle = Bundle(url: url) else { continue }
                let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? (entry as NSString).deletingPathExtension
                let id = bundle.bundleIdentifier ?? path
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 32, height: 32)
                found.append(LaunchableApp(id: id, name: name, url: url, icon: icon))
            }
        }
        apps = found.sorted { lhs, rhs in
            let lhsPinned = pinnedIDs.contains(lhs.id)
            let rhsPinned = pinnedIDs.contains(rhs.id)
            if lhsPinned != rhsPinned { return lhsPinned }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func filteredApps(_ query: String) -> [LaunchableApp] {
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func isPinned(_ app: LaunchableApp) -> Bool {
        pinnedIDs.contains(app.id)
    }

    func togglePin(_ app: LaunchableApp) {
        if pinnedIDs.contains(app.id) {
            pinnedIDs.remove(app.id)
        } else {
            pinnedIDs.insert(app.id)
        }
        UserDefaults.standard.set(Array(pinnedIDs), forKey: pinnedDefaultsKey)
        refresh()
    }

    /// Launches an app "inside" AppRunner's session: AppRunner owns the
    /// NSRunningApplication handle so it can list, focus, and terminate the
    /// app from the compact notch strip instead of the user hunting for it
    /// in the Dock or Mission Control.
    func launch(_ app: LaunchableApp) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: config) { [weak self] runningApp, error in
            guard let self, let runningApp, error == nil else { return }
            Task { @MainActor in
                self.running[runningApp.processIdentifier] = app
                self.observeTermination(of: runningApp)
            }
        }
    }

    func focus(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.activate()
    }

    func quit(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.terminate()
    }

    private func observeTermination(of runningApp: NSRunningApplication) {
        let pid = runningApp.processIdentifier
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let terminated = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  terminated.processIdentifier == pid else { return }
            guard let self else { return }
            Task { @MainActor in
                self.running.removeValue(forKey: pid)
            }
        }
    }
}

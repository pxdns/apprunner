import AppKit
import Foundation

/// Builds tiny "shim" .app bundles that show up in the Dock / menu-bar
/// title bar under a custom name and icon, but just forward a double-click
/// to the real target app. macOS reads the name shown next to the Apple
/// menu straight from the *running* app's own bundle — there's no public
/// API to rename another process's title live — so a lightweight wrapper
/// bundle is the supported way to get a custom name without duplicating
/// the (often huge) real app.
enum AppShortcutBuilder {
    static var shortcutsDirectory: URL {
        let dir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/AppRunner Shortcuts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    enum BuildError: LocalizedError {
        case invalidName
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidName: return "Enter a valid shortcut name."
            case .writeFailed(let reason): return "Couldn't create the shortcut: \(reason)"
            }
        }
    }

    @discardableResult
    static func makeShortcut(for target: LaunchableApp, named name: String) throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BuildError.invalidName }

        let fm = FileManager.default
        let bundleURL = shortcutsDirectory.appendingPathComponent("\(trimmed).app")
        let contents = bundleURL.appendingPathComponent("Contents")
        let macOS = contents.appendingPathComponent("MacOS")
        let resources = contents.appendingPathComponent("Resources")

        do {
            try? fm.removeItem(at: bundleURL)
            try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
            try fm.createDirectory(at: resources, withIntermediateDirectories: true)

            let iconName = copyIcon(from: target, into: resources)

            let plist: [String: Any] = [
                "CFBundleName": trimmed,
                "CFBundleDisplayName": trimmed,
                "CFBundleIdentifier": "dev.apprunner.shortcut.\(UUID().uuidString)",
                "CFBundleVersion": "1.0",
                "CFBundleShortVersionString": "1.0",
                "CFBundlePackageType": "APPL",
                "CFBundleExecutable": "launch",
                "LSUIElement": false,
                "CFBundleIconFile": iconName ?? ""
            ]
            let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try plistData.write(to: contents.appendingPathComponent("Info.plist"))

            let launcherScript = """
            #!/bin/sh
            exec open -b "\(bundleIdentifierOrPath(for: target))" "$@"
            """
            let launcherURL = macOS.appendingPathComponent("launch")
            try launcherScript.write(to: launcherURL, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcherURL.path)

            return bundleURL
        } catch {
            throw BuildError.writeFailed(error.localizedDescription)
        }
    }

    static func removeShortcut(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func bundleIdentifierOrPath(for target: LaunchableApp) -> String {
        if let bundle = Bundle(url: target.url), let id = bundle.bundleIdentifier {
            return id
        }
        return target.url.path
    }

    /// Copies the target app's own .icns into the shortcut so it doesn't
    /// inherit the generic document icon; falls back silently if not found.
    private static func copyIcon(from target: LaunchableApp, into resources: URL) -> String? {
        guard let bundle = Bundle(url: target.url) else { return nil }
        var iconFile = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String ?? "AppIcon"
        if !iconFile.hasSuffix(".icns") { iconFile += ".icns" }
        let sourceURL = bundle.bundleURL.appendingPathComponent("Contents/Resources/\(iconFile)")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }
        let destName = "AppIcon.icns"
        let destURL = resources.appendingPathComponent(destName)
        try? FileManager.default.copyItem(at: sourceURL, to: destURL)
        return destName
    }
}

import SwiftUI

/// A curated list of common now-playing sources, mapped to real bundle
/// IDs, for the "preferred source" picker. "Automatic" (nil ID) shows
/// whatever app the system reports; anything else filters to just that app.
struct NowPlayingSource: Identifiable, Hashable {
    let id: String? // nil = automatic
    let name: String

    static let automatic = NowPlayingSource(id: nil, name: "Automatic (any app)")
    static let curated: [NowPlayingSource] = [
        .automatic,
        NowPlayingSource(id: "com.apple.Music", name: "Music"),
        NowPlayingSource(id: "com.spotify.client", name: "Spotify"),
        NowPlayingSource(id: "com.google.Chrome", name: "Chrome"),
        NowPlayingSource(id: "com.apple.Safari", name: "Safari"),
        NowPlayingSource(id: "com.apple.podcasts", name: "Podcasts"),
        NowPlayingSource(id: "com.apple.TV", name: "TV")
    ]
}

/// Persisted notch customization: accent color, corner rounding, how big
/// the hover/expanded states are, which terminal theme to use, and which
/// app the now-playing widget should listen to.
@MainActor
final class NotchSettingsStore: ObservableObject {
    @Published var accentHex: UInt32 {
        didSet { UserDefaults.standard.set(accentHex, forKey: Keys.accent) }
    }
    @Published var cornerRadius: Double {
        didSet { UserDefaults.standard.set(cornerRadius, forKey: Keys.corner) }
    }
    @Published var expandedWidth: Double {
        didSet { UserDefaults.standard.set(expandedWidth, forKey: Keys.width) }
    }
    @Published var expandedHeight: Double {
        didSet { UserDefaults.standard.set(expandedHeight, forKey: Keys.height) }
    }
    @Published var hoverSidePadding: Double {
        didSet { UserDefaults.standard.set(hoverSidePadding, forKey: Keys.hoverPadding) }
    }
    /// Manual drag offset from the default top-center position, in points
    /// (positive x = right, positive y = down). Lets you park the notch
    /// wherever you actually want it instead of always dead-center.
    @Published var offsetX: Double {
        didSet { UserDefaults.standard.set(offsetX, forKey: Keys.offsetX) }
    }
    @Published var offsetY: Double {
        didSet { UserDefaults.standard.set(offsetY, forKey: Keys.offsetY) }
    }
    @Published var terminalThemeID: String {
        didSet { UserDefaults.standard.set(terminalThemeID, forKey: Keys.theme) }
    }
    /// nil/empty = automatic (any app); otherwise a bundle identifier.
    @Published var preferredNowPlayingSourceID: String? {
        didSet { UserDefaults.standard.set(preferredNowPlayingSourceID, forKey: Keys.nowPlayingSource) }
    }
    /// Free-text custom bundle ID, kept separately so switching back to a
    /// curated entry doesn't lose what you typed.
    @Published var customSourceBundleID: String {
        didSet { UserDefaults.standard.set(customSourceBundleID, forKey: Keys.customSource) }
    }

    var terminalTheme: TerminalTheme { .theme(id: terminalThemeID) }
    var accentColor: Color { Color(nsColor: NSColor(hex: accentHex)) }

    private enum Keys {
        static let accent = "AppRunner.notch.accentHex"
        static let corner = "AppRunner.notch.cornerRadius"
        static let width = "AppRunner.notch.expandedWidth"
        static let height = "AppRunner.notch.expandedHeight"
        static let hoverPadding = "AppRunner.notch.hoverSidePadding"
        static let offsetX = "AppRunner.notch.offsetX"
        static let offsetY = "AppRunner.notch.offsetY"
        static let theme = "AppRunner.notch.terminalTheme"
        static let nowPlayingSource = "AppRunner.notch.nowPlayingSource"
        static let customSource = "AppRunner.notch.customSourceBundleID"
    }

    init() {
        let d = UserDefaults.standard
        accentHex = d.object(forKey: Keys.accent) != nil ? UInt32(d.integer(forKey: Keys.accent)) : 0x0A84FF
        cornerRadius = d.object(forKey: Keys.corner) != nil ? d.double(forKey: Keys.corner) : 14
        expandedWidth = d.object(forKey: Keys.width) != nil ? d.double(forKey: Keys.width) : 460
        expandedHeight = d.object(forKey: Keys.height) != nil ? d.double(forKey: Keys.height) : 320
        hoverSidePadding = d.object(forKey: Keys.hoverPadding) != nil ? d.double(forKey: Keys.hoverPadding) : 110
        offsetX = d.double(forKey: Keys.offsetX)
        offsetY = d.double(forKey: Keys.offsetY)
        terminalThemeID = d.string(forKey: Keys.theme) ?? TerminalTheme.ghosttyDark.id
        preferredNowPlayingSourceID = d.string(forKey: Keys.nowPlayingSource)
        customSourceBundleID = d.string(forKey: Keys.customSource) ?? ""
    }
}

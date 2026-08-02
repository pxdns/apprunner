import SwiftUI

/// Persisted notch customization: accent color, corner rounding, how big
/// the expanded panel is, and which terminal theme to use.
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
    @Published var terminalThemeID: String {
        didSet { UserDefaults.standard.set(terminalThemeID, forKey: Keys.theme) }
    }

    var terminalTheme: TerminalTheme { .theme(id: terminalThemeID) }
    var accentColor: Color { Color(nsColor: NSColor(hex: accentHex)) }

    private enum Keys {
        static let accent = "AppRunner.notch.accentHex"
        static let corner = "AppRunner.notch.cornerRadius"
        static let width = "AppRunner.notch.expandedWidth"
        static let height = "AppRunner.notch.expandedHeight"
        static let theme = "AppRunner.notch.terminalTheme"
    }

    init() {
        let d = UserDefaults.standard
        accentHex = d.object(forKey: Keys.accent) != nil ? UInt32(d.integer(forKey: Keys.accent)) : 0x0A84FF
        cornerRadius = d.object(forKey: Keys.corner) != nil ? d.double(forKey: Keys.corner) : 14
        expandedWidth = d.object(forKey: Keys.width) != nil ? d.double(forKey: Keys.width) : 460
        expandedHeight = d.object(forKey: Keys.height) != nil ? d.double(forKey: Keys.height) : 320
        terminalThemeID = d.string(forKey: Keys.theme) ?? TerminalTheme.ghosttyDark.id
    }
}

import AppKit
import SwiftTerm

/// A handful of well-known terminal color schemes. "Ghostty Dark" here is
/// a hand-picked palette matching Ghostty's default dark theme look
/// (not the Ghostty source itself — there's no public Swift package for
/// it — just the same kind of high-contrast, slightly warm palette).
struct TerminalTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let backgroundHex: UInt32
    let foregroundHex: UInt32
    let ansiHex: [UInt32] // 16 entries: 0-7 normal, 8-15 bright

    var background: NSColor { NSColor(hex: backgroundHex) }
    var foreground: NSColor { NSColor(hex: foregroundHex) }
    var ansiColors: [SwiftTerm.Color] { ansiHex.map { SwiftTerm.Color(hex: $0) } }

    static let ghosttyDark = TerminalTheme(
        id: "ghostty-dark",
        name: "Ghostty Dark",
        backgroundHex: 0x1D1F21,
        foregroundHex: 0xE4E4E4,
        ansiHex: [
            0x1D1F21, 0xCC6666, 0xB5BD68, 0xF0C674,
            0x81A2BE, 0xB294BB, 0x8ABEB7, 0xC5C8C6,
            0x969896, 0xD54E53, 0xB9CA4A, 0xE7C547,
            0x7AA6DA, 0xC397D8, 0x70C0B1, 0xEAEAEA
        ]
    )

    static let dracula = TerminalTheme(
        id: "dracula",
        name: "Dracula",
        backgroundHex: 0x282A36,
        foregroundHex: 0xF8F8F2,
        ansiHex: [
            0x21222C, 0xFF5555, 0x50FA7B, 0xF1FA8C,
            0xBD93F9, 0xFF79C6, 0x8BE9FD, 0xF8F8F2,
            0x6272A4, 0xFF6E6E, 0x69FF94, 0xFFFFA5,
            0xD6ACFF, 0xFF92DF, 0xA4FFFF, 0xFFFFFF
        ]
    )

    static let solarizedDark = TerminalTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        backgroundHex: 0x002B36,
        foregroundHex: 0x839496,
        ansiHex: [
            0x073642, 0xDC322F, 0x859900, 0xB58900,
            0x268BD2, 0xD33682, 0x2AA198, 0xEEE8D5,
            0x002B36, 0xCB4B16, 0x586E75, 0x657B83,
            0x839496, 0x6C71C4, 0x93A1A1, 0xFDF6E3
        ]
    )

    static let nord = TerminalTheme(
        id: "nord",
        name: "Nord",
        backgroundHex: 0x2E3440,
        foregroundHex: 0xD8DEE9,
        ansiHex: [
            0x3B4252, 0xBF616A, 0xA3BE8C, 0xEBCB8B,
            0x81A1C1, 0xB48EAD, 0x88C0D0, 0xE5E9F0,
            0x4C566A, 0xBF616A, 0xA3BE8C, 0xEBCB8B,
            0x81A1C1, 0xB48EAD, 0x8FBCBB, 0xECEFF4
        ]
    )

    static let all: [TerminalTheme] = [.ghosttyDark, .dracula, .solarizedDark, .nord]

    static func theme(id: String) -> TerminalTheme {
        all.first { $0.id == id } ?? .ghosttyDark
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension SwiftTerm.Color {
    init(hex: UInt32) {
        func component(_ shift: UInt32) -> UInt16 {
            UInt16(((hex >> shift) & 0xFF)) * 257 // scale 0...255 to 0...65535
        }
        self.init(red: component(16), green: component(8), blue: component(0))
    }
}

import AppKit
import SwiftUI
import SwiftTerm

/// Bridges SwiftTerm's AppKit `LocalProcessTerminalView` — a real
/// VT100/xterm emulator with a pty-backed shell, scrollback, mouse
/// reporting, resizing, etc. — into SwiftUI, instead of the old
/// hand-rolled raw-text pty reader.
struct TerminalHostView: NSViewRepresentable {
    var theme: TerminalTheme

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = context.coordinator
        apply(theme, to: view)

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        view.startProcess(executable: shell, args: ["-il"])
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        apply(theme, to: nsView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func apply(_ theme: TerminalTheme, to view: LocalProcessTerminalView) {
        view.nativeForegroundColor = theme.foreground
        view.nativeBackgroundColor = theme.background
        view.getTerminal().installPalette(colors: theme.ansiColors)
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}

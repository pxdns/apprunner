import SwiftUI

/// A minimal, dependency-free terminal: no ANSI/VT100 rendering, just raw
/// shell I/O over a real pty. Enough to run builds, git, ls, etc. from the
/// notch without alt-tabbing to Terminal.app.
struct TerminalView: View {
    @StateObject private var session = ShellSession()
    @State private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(session.output.isEmpty ? "$ " : session.output)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("bottom")
                }
                .onChange(of: session.output) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .frame(height: 200)
            .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Text(">").foregroundStyle(.green).font(.system(size: 11, design: .monospaced))
                TextField("command", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .focused($inputFocused)
                    .onSubmit(runCommand)
            }
            .padding(6)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .onAppear {
            session.start()
            inputFocused = true
        }
        .onDisappear {
            session.stop()
        }
    }

    private func runCommand() {
        guard !input.isEmpty else { return }
        session.send(input)
        input = ""
    }
}

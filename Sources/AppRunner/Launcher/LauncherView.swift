import AppKit
import SwiftUI

/// Compact grid of installed apps plus a strip of apps currently running
/// "inside" the launcher session. This is the space-saving piece: one
/// small panel replaces Dock icons, Spotlight, and Mission Control for the
/// common case of "open this app, glance at what's open".
struct LauncherView: View {
    @ObservedObject var appLibrary: AppLibrary
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 56, maximum: 56), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps…", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            if !appLibrary.running.isEmpty {
                runningStrip
                Divider().opacity(0.3)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(appLibrary.filteredApps(query)) { app in
                        AppIconButton(app: app) {
                            appLibrary.launch(app)
                        }
                        .contextMenu {
                            Button(appLibrary.isPinned(app) ? "Unpin" : "Pin to Top") {
                                appLibrary.togglePin(app)
                            }
                            Button("Create Renamed Shortcut…") {
                                promptForRename(app)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 220)
        }
    }

    /// Uses NSAlert for the name prompt rather than a SwiftUI sheet — the
    /// notch is a borderless NSPanel, and a native alert anchors reliably
    /// on top of it without extra window-management plumbing.
    private func promptForRename(_ app: LaunchableApp) {
        let alert = NSAlert()
        alert.messageText = "Rename \"\(app.name)\""
        alert.informativeText = "Creates a small shortcut app with this name that opens \(app.name)."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = app.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try AppShortcutBuilder.makeShortcut(for: app, named: field.stringValue)
                appLibrary.refresh()
            } catch {
                let failure = NSAlert()
                failure.messageText = "Couldn't create shortcut"
                failure.informativeText = error.localizedDescription
                failure.runModal()
            }
        }
    }

    private var runningStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(appLibrary.running.keys), id: \.self) { pid in
                    if let app = appLibrary.running[pid] {
                        RunningAppChip(app: app, pid: pid, appLibrary: appLibrary)
                    }
                }
            }
        }
    }
}

private struct AppIconButton: View {
    let app: LaunchableApp
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                Text(app.name)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .frame(width: 54)
            }
        }
        .buttonStyle(.plain)
        .help(app.name)
    }
}

private struct RunningAppChip: View {
    let app: LaunchableApp
    let pid: pid_t
    let appLibrary: AppLibrary

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 16, height: 16)
            Text(app.name)
                .font(.system(size: 10))
            Button {
                appLibrary.quit(pid: pid)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.white.opacity(0.1), in: Capsule())
        .onTapGesture {
            appLibrary.focus(pid: pid)
        }
    }
}

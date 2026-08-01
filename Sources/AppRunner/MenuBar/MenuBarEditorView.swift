import AppKit
import SwiftUI

/// Lets you hide or rename the frontmost app's menu bar items — including
/// its bold application-name menu, e.g. "Chrome" — without touching that
/// app's bundle. Backed by MenuBarOverlayController + MenuBarClickGuard,
/// which read the store this view writes to.
struct MenuBarEditorView: View {
    @ObservedObject var store: MenuBarCustomizationStore
    @StateObject private var model = MenuBarEditorModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !AccessibilityPermission.isTrusted {
                Text("AppRunner needs Accessibility access to read and patch another app's menu bar.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Grant Accessibility Access…") {
                    AccessibilityPermission.requestIfNeeded()
                }
            } else if let bundleID = model.bundleID {
                Text(model.appName)
                    .font(.system(size: 12, weight: .semibold))
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.items) { item in
                            row(for: item, bundleID: bundleID)
                        }
                    }
                }
                .frame(maxHeight: 220)
            } else {
                Text("Switch to another app to edit its menu bar.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func row(for item: MenuBarItemInfo, bundleID: String) -> some View {
        let rule = store.rule(bundleID: bundleID, title: item.title)
        return HStack(spacing: 6) {
            Text(item.title)
                .font(.system(size: 11))
                .strikethrough(rule.hidden)
                .frame(width: 68, alignment: .leading)

            TextField("Rename", text: Binding(
                get: { rule.renamedTo ?? "" },
                set: { store.setRename($0, bundleID: bundleID, title: item.title) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .disabled(rule.hidden)

            Toggle("", isOn: Binding(
                get: { rule.hidden },
                set: { store.setHidden($0, bundleID: bundleID, title: item.title) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }
}

@MainActor
private final class MenuBarEditorModel: ObservableObject {
    @Published var appName = ""
    @Published var bundleID: String?
    @Published var items: [MenuBarItemInfo] = []

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              let bundleID = app.bundleIdentifier else {
            appName = ""
            self.bundleID = nil
            items = []
            return
        }
        appName = app.localizedName ?? "App"
        self.bundleID = bundleID
        items = MenuBarInspector.menuBarItems(for: app.processIdentifier)
    }
}

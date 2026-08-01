import Foundation

/// Persists per-app menu bar rules (hide / rename), keyed by bundle
/// identifier then by the item's real title. Nothing here touches the
/// target app itself — it's just AppRunner's own preference data, so
/// there's no risk of corrupting anything by editing or deleting it.
@MainActor
final class MenuBarCustomizationStore: ObservableObject {
    struct Rule: Codable, Equatable {
        var hidden: Bool = false
        var renamedTo: String?

        var isNoOp: Bool { !hidden && (renamedTo?.isEmpty ?? true) }
    }

    @Published private(set) var rules: [String: [String: Rule]] = [:]

    private let defaultsKey = "AppRunner.menuBarRules"

    init() {
        load()
    }

    func rule(bundleID: String, title: String) -> Rule {
        rules[bundleID]?[title] ?? Rule()
    }

    func setHidden(_ hidden: Bool, bundleID: String, title: String) {
        var rule = rule(bundleID: bundleID, title: title)
        rule.hidden = hidden
        apply(rule, bundleID: bundleID, title: title)
    }

    func setRename(_ name: String, bundleID: String, title: String) {
        var rule = rule(bundleID: bundleID, title: title)
        rule.renamedTo = name.isEmpty ? nil : name
        apply(rule, bundleID: bundleID, title: title)
    }

    private func apply(_ rule: Rule, bundleID: String, title: String) {
        var forApp = rules[bundleID] ?? [:]
        if rule.isNoOp {
            forApp.removeValue(forKey: title)
        } else {
            forApp[title] = rule
        }
        rules[bundleID] = forApp.isEmpty ? nil : forApp
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String: Rule]].self, from: data) else { return }
        rules = decoded
    }
}

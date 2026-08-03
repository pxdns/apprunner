import SwiftUI

/// Lets something outside the SwiftUI tree (the status bar menu) tell the
/// notch panel to open directly to a specific tab, instead of only being
/// reachable by clicking the notch itself.
@MainActor
final class NotchNavigator: ObservableObject {
    @Published var requestedTab: NotchTab?

    func open(_ tab: NotchTab) {
        requestedTab = tab
    }
}

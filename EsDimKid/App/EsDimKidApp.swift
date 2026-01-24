import SwiftUI

@main
struct EsDimKidApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dimmingManager = DimmingManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(dimmingManager)
        } label: {
            Image(systemName: dimmingManager.isEnabled ? "circle.lefthalf.filled" : "circle")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(dimmingManager)
        }
    }
}

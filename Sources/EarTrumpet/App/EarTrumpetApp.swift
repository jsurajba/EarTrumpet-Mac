import SwiftUI
import AppKit

@main
struct EarTrumpetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a menu bar accessory application (no main dock icon by default)
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
    }
}

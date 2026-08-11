import AppKit
import SwiftUI

public final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    private let audioEngine = AudioEngine.shared
    private let appVolumeManager = AppVolumeManager.shared
    
    public override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        setupHotKeys()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            if let image = NSImage(systemSymbolName: "tuningfork", accessibilityDescription: "EarTrumpet")?.withSymbolConfiguration(config) {
                button.image = image
            } else if let fallback = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "EarTrumpet")?.withSymbolConfiguration(config) {
                button.image = fallback
            }
            
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Add scroll wheel monitor over menu bar button
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self = self, let button = self.statusItem.button else { return event }
                let mouseLocation = NSEvent.mouseLocation
                if NSPointInRect(mouseLocation, button.window?.frame ?? .zero) {
                    let delta = Float(event.deltaY) * 0.02
                    let newVol = max(0.0, min(1.0, self.audioEngine.masterVolume + delta))
                    self.audioEngine.masterVolume = newVol
                    return nil
                }
                return event
            }
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.animates = true
        
        let flyoutView = VolumeFlyoutView(
            audioEngine: audioEngine,
            appVolumeManager: appVolumeManager
        )
        
        popover.contentViewController = NSHostingController(rootView: flyoutView)
    }
    
    private func setupHotKeys() {
        HotKeyManager.shared.onHotKeyTriggered = { [weak self] in
            self?.togglePopover()
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }
    
    public func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            audioEngine.refreshDevices()
            appVolumeManager.refreshAppList()
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "EarTrumpet 2.3.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        let openItem = NSMenuItem(title: "Open EarTrumpet", action: #selector(openFlyoutAction), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let aboutItem = NSMenuItem(title: "About EarTrumpet", action: #selector(openAboutAction), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit EarTrumpet", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so normal clicks toggle popover again
    }
    
    @objc private func openFlyoutAction() {
        togglePopover()
    }
    
    @objc private func openSettingsAction() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "EarTrumpet Preferences"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func openAboutAction() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "About EarTrumpet"
        window.contentView = NSHostingView(rootView: AboutView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}

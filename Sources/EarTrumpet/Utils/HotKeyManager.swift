import AppKit
import Carbon

public final class HotKeyManager {
    public static let shared = HotKeyManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    public var onHotKeyTriggered: (() -> Void)?
    
    private init() {
        registerHotKey()
    }
    
    deinit {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
    
    public func registerHotKey() {
        // Option + Shift + V shortcut
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.option, .shift]) && event.keyCode == kVK_ANSI_V {
                DispatchQueue.main.async {
                    self?.onHotKeyTriggered?()
                }
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.option, .shift]) && event.keyCode == kVK_ANSI_V {
                DispatchQueue.main.async {
                    self?.onHotKeyTriggered?()
                }
                return nil
            }
            return event
        }
    }
}

import SwiftUI
import AppKit

public struct VolumeFlyoutView: View {
    @ObservedObject var audioEngine: AudioEngine
    @ObservedObject var appVolumeManager: AppVolumeManager
    
    @AppStorage("EarTrumpet_AccentColor") private var accentColorHex: String = "#008080"
    @AppStorage("EarTrumpet_ShowingSettings") private var showingSettings: Bool = false
    
    private var accentColor: Color {
        Color(hex: accentColorHex) ?? .teal
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tuningfork")
                        .foregroundColor(accentColor)
                        .font(.system(size: 15, weight: .bold))
                    
                    Text("EarTrumpet")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                // Diagnostics Button
                Button(action: {
                    openDiagnosticsWindow()
                }) {
                    Image(systemName: "terminal")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Live Audio Diagnostics")
                
                // Refresh Apps Button
                Button(action: {
                    audioEngine.refreshDevices()
                    appVolumeManager.refreshAppList()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh Audio Devices & Apps")
                
                // Settings Button
                Button(action: {
                    openSettingsWindow()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Preferences")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    // Master Audio Volume Control
                    MasterVolumeView(audioEngine: audioEngine)
                    
                    // Section Title
                    HStack {
                        Text("Applications & Sessions")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(appVolumeManager.appSessions.count)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    
                    // Per-App Volume Controls List
                    if appVolumeManager.appSessions.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "waveform")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("No active audio applications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(appVolumeManager.appSessions) { session in
                                AppVolumeRowView(
                                    session: session,
                                    appVolumeManager: appVolumeManager,
                                    audioEngine: audioEngine
                                )
                            }
                        }
                    }
                }
                .padding(12)
            }
            
            Divider()
            
            // Footer Bar
            HStack {
                Button(action: {
                    openSystemSoundSettings()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("macOS Sound Settings")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(accentColor)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit EarTrumpet")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 360, height: 480)
        .background(.ultraThinMaterial)
    }
    
    private func openSystemSoundSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openSettingsWindow() {
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
    
    private func openDiagnosticsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "EarTrumpet Live Audio Diagnostics"
        window.contentView = NSHostingView(rootView: DiagnosticConsoleView(audioEngine: audioEngine))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

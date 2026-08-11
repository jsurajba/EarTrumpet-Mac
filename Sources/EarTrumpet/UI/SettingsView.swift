import SwiftUI

public struct SettingsView: View {
    @AppStorage("EarTrumpet_AccentColor") private var accentColorHex: String = "#008080"
    @AppStorage("EarTrumpet_LaunchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("EarTrumpet_ScrollToChangeVolume") private var scrollToChangeVolume: Bool = true
    @AppStorage("EarTrumpet_HotkeyEnabled") private var hotkeyEnabled: Bool = true
    @AppStorage("EarTrumpet_SelectedSettingsTab") private var selectedTab: Int = 0
    
    private let accentColors: [(name: String, hex: String, color: Color)] = [
        ("Teal (EarTrumpet)", "#008080", .teal),
        ("System Blue", "#007AFF", .blue),
        ("Purple", "#AF52DE", .purple),
        ("Coral", "#FF6B6B", .red),
        ("Graphite", "#8E8E93", .gray)
    ]
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // General & Appearance
            Form {
                Section("Appearance & Theme") {
                    Picker("Accent Color", selection: $accentColorHex) {
                        ForEach(accentColors, id: \.hex) { item in
                            HStack {
                                Circle().fill(item.color).frame(width: 12, height: 12)
                                Text(item.name)
                            }
                            .tag(item.hex)
                        }
                    }
                }
                
                Section("Behavior") {
                    Toggle("Launch EarTrumpet at Login", isOn: $launchAtLogin)
                    Toggle("Scroll over Menu Bar icon to change Master Volume", isOn: $scrollToChangeVolume)
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .tag(0)
            
            // Hotkeys
            Form {
                Section("Shortcuts") {
                    Toggle("Enable Global Flyout Hotkey", isOn: $hotkeyEnabled)
                    
                    HStack {
                        Text("Open EarTrumpet Flyout:")
                        Spacer()
                        Text("⌥ + ⇧ + V (Option + Shift + V)")
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .tabItem {
                Label("Shortcuts", systemImage: "keyboard")
            }
            .tag(1)
            
            // About & Credits
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }
        .frame(width: 460, height: 400)
    }
}

// Color Hex Extension
extension Color {
    init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if cleanHex.count == 6 {
            cleanHex += "FF"
        }
        guard cleanHex.count == 8, let val = UInt64(cleanHex, radix: 16) else { return nil }
        let r = Double((val & 0xFF000000) >> 24) / 255.0
        let g = Double((val & 0x00FF0000) >> 16) / 255.0
        let b = Double((val & 0x0000FF00) >> 8) / 255.0
        let a = Double(val & 0x000000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

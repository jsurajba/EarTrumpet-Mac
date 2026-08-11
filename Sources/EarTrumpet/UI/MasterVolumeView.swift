import SwiftUI

public struct MasterVolumeView: View {
    @ObservedObject var audioEngine: AudioEngine
    @AppStorage("EarTrumpet_AccentColor") private var accentColorHex: String = "#008080"
    
    private var accentColor: Color {
        Color(hex: accentColorHex) ?? .teal
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: Master Title & Output Device Selector Menu
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: audioEngine.defaultOutputDevice?.type.iconName ?? "speaker.wave.2.fill")
                        .foregroundColor(accentColor)
                        .font(.system(size: 15, weight: .semibold))
                    
                    Text(audioEngine.defaultOutputDevice?.name ?? "System Output")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Device dropdown picker
                Menu {
                    Text("Select Output Device")
                        .font(.caption)
                    Divider()
                    
                    ForEach(audioEngine.outputDevices) { device in
                        Button(action: {
                            audioEngine.setDefaultOutputDevice(device)
                        }) {
                            HStack {
                                Image(systemName: device.type.iconName)
                                Text(device.name)
                                if device.isDefault {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Output")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
            }
            
            // Middle row: Mute button + Master Slider + Volume percentage
            HStack(spacing: 12) {
                Button(action: {
                    audioEngine.setMasterMute(!audioEngine.isMasterMuted)
                }) {
                    Image(systemName: audioEngine.isMasterMuted ? "speaker.slash.fill" : volumeIcon(for: audioEngine.masterVolume))
                        .font(.system(size: 16))
                        .foregroundColor(audioEngine.isMasterMuted ? .secondary : accentColor)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                
                Slider(
                    value: Binding(
                        get: { Double(audioEngine.masterVolume) },
                        set: { audioEngine.setMasterVolume(Float($0)) }
                    ),
                    in: 0.0...1.0
                )
                .accentColor(accentColor)
                
                Text("\(Int(audioEngine.masterVolume * 100))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
            
            // Bottom peak level audio meter bar
            AudioMeterView(
                level: audioEngine.isMasterMuted ? 0.0 : audioEngine.masterPeakLevel,
                accentColor: accentColor,
                height: 4.0
            )
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
    }
    
    private func volumeIcon(for vol: Float) -> String {
        if vol == 0 { return "speaker.slash.fill" }
        if vol < 0.33 { return "speaker.wave.1.fill" }
        if vol < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

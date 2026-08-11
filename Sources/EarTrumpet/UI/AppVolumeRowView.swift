import SwiftUI
import CoreAudio

public struct AppVolumeRowView: View {
    public let session: AppAudioSession
    @ObservedObject var appVolumeManager: AppVolumeManager
    @ObservedObject var audioEngine: AudioEngine
    
    @AppStorage("EarTrumpet_AccentColor") private var accentColorHex: String = "#008080"
    
    private var accentColor: Color {
        Color(hex: accentColorHex) ?? .teal
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Application App Icon
                if let nsIcon = session.icon {
                    Image(nsImage: nsIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                } else {
                    Image(systemName: session.isSystemSound ? "speaker.wave.2.circle.fill" : "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(accentColor)
                }
                
                // Application Name
                Text(session.appName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                
                Spacer()
                
                // Per-App Output Device Routing Dropdown
                if !session.isSystemSound {
                    Menu {
                        Text("Audio Device Routing")
                            .font(.caption)
                        Divider()
                        
                        Button(action: {
                            appVolumeManager.setTargetDevice(for: session.id, deviceID: nil)
                        }) {
                            HStack {
                                Text("Default System Output")
                                if session.targetDeviceId == nil {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        ForEach(audioEngine.outputDevices) { device in
                            Button(action: {
                                appVolumeManager.setTargetDevice(for: session.id, deviceID: device.id)
                            }) {
                                HStack {
                                    Image(systemName: device.type.iconName)
                                    Text(device.name)
                                    if session.targetDeviceId == device.id {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: currentRoutingIcon())
                                .font(.system(size: 9))
                            Text(currentRoutingName())
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            
            // Slider + Mute + Percentage
            HStack(spacing: 10) {
                Button(action: {
                    appVolumeManager.toggleMute(for: session.id)
                }) {
                    Image(systemName: session.isMuted ? "speaker.slash.fill" : volumeIcon(for: session.volume))
                        .font(.system(size: 14))
                        .foregroundColor(session.isMuted ? .secondary : accentColor)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                
                Slider(
                    value: Binding(
                        get: { Double(session.volume) },
                        set: { appVolumeManager.setVolume(for: session.id, volume: Float($0)) }
                    ),
                    in: 0.0...1.0
                )
                .accentColor(accentColor)
                
                Text("\(Int(session.volume * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
            
            // Per-App Peak Audio Meter
            AudioMeterView(
                level: session.isMuted ? 0.0 : session.peakLevel,
                accentColor: accentColor,
                height: 3.0
            )
        }
        .padding(8)
        .background(Color.primary.opacity(0.025))
        .cornerRadius(8)
    }
    
    private func volumeIcon(for vol: Float) -> String {
        if vol == 0 { return "speaker.slash.fill" }
        if vol < 0.33 { return "speaker.wave.1.fill" }
        if vol < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
    
    private func currentRoutingName() -> String {
        if let devID = session.targetDeviceId, let dev = audioEngine.outputDevices.first(where: { $0.id == devID }) {
            return dev.name
        }
        return "Default"
    }
    
    private func currentRoutingIcon() -> String {
        if let devID = session.targetDeviceId, let dev = audioEngine.outputDevices.first(where: { $0.id == devID }) {
            return dev.type.iconName
        }
        return "arrow.triangle.branch"
    }
}

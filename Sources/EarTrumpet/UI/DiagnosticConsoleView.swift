import SwiftUI

public struct DiagnosticConsoleView: View {
    @ObservedObject var audioEngine: AudioEngine = AudioEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.teal)
                Text("EarTrumpet Live Audio Diagnostics")
                    .font(.system(size: 15, weight: .bold))
                
                Spacer()
                
                Button("Clear") {
                    // Refresh
                    audioEngine.refreshDevices()
                }
                .font(.caption)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Device Information Summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Default Output Device: \(audioEngine.defaultOutputDevice?.name ?? "None") (ID: \(audioEngine.defaultOutputDevice?.id ?? 0))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text("Master Volume: \(Int(audioEngine.masterVolume * 100))% | Muted: \(audioEngine.isMasterMuted ? "Yes" : "No") | Output Count: \(audioEngine.outputDevices.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(6)
            
            Divider()
            
            Text("Real-Time Control & Hardware Log:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(audioEngine.diagnosticLogs) { log in
                            HStack(alignment: .top, spacing: 6) {
                                Text(log.timestamp)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.teal)
                                Text(log.message)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            .id(log.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                }
                .background(Color.black.opacity(0.85))
                .cornerRadius(6)
                .onChange(of: audioEngine.diagnosticLogs.count) { _ in
                    if let last = audioEngine.diagnosticLogs.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 520, height: 380)
    }
}

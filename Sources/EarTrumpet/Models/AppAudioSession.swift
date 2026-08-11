import Foundation
import AppKit
import CoreAudio

public struct AppAudioSession: Identifiable, Equatable {
    public let id: String
    public let pid: pid_t
    public let appName: String
    public let bundleIdentifier: String?
    public var icon: NSImage?
    public var volume: Float // 0.0 to 1.0
    public var isMuted: Bool
    public var peakLevel: Float // 0.0 to 1.0 for real-time audio meter
    public var targetDeviceId: AudioDeviceID? // Custom routing output device
    public let isSystemSound: Bool
    
    public init(
        id: String,
        pid: pid_t,
        appName: String,
        bundleIdentifier: String? = nil,
        icon: NSImage? = nil,
        volume: Float = 1.0,
        isMuted: Bool = false,
        peakLevel: Float = 0.0,
        targetDeviceId: AudioDeviceID? = nil,
        isSystemSound: Bool = false
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.volume = volume
        self.isMuted = isMuted
        self.peakLevel = peakLevel
        self.targetDeviceId = targetDeviceId
        self.isSystemSound = isSystemSound
    }
    
    public static func == (lhs: AppAudioSession, rhs: AppAudioSession) -> Bool {
        return lhs.id == rhs.id
    }
}

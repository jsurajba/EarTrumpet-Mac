import Foundation
import CoreAudio

public enum AudioDeviceType: String, Codable, CaseIterable {
    case builtInSpeaker = "Built-in Speaker"
    case headphones = "Headphones"
    case bluetooth = "Bluetooth"
    case hdmiDisplay = "Display / HDMI"
    case virtual = "Virtual Audio"
    case unknown = "Audio Output"
    
    public var iconName: String {
        switch self {
        case .builtInSpeaker: return "speaker.wave.2.fill"
        case .headphones: return "headphones"
        case .bluetooth: return "wave.3.right.circle.fill"
        case .hdmiDisplay: return "tv.fill"
        case .virtual: return "arrow.triangle.branch"
        case .unknown: return "speaker.fill"
        }
    }
}

public struct AudioDevice: Identifiable, Hashable, Equatable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let type: AudioDeviceType
    public let isOutput: Bool
    public var volume: Float // 0.0 to 1.0
    public var isMuted: Bool
    public var isDefault: Bool
    
    public init(id: AudioDeviceID, uid: String, name: String, type: AudioDeviceType, isOutput: Bool, volume: Float = 1.0, isMuted: Bool = false, isDefault: Bool = false) {
        self.id = id
        self.uid = uid
        self.name = name
        self.type = type
        self.isOutput = isOutput
        self.volume = volume
        self.isMuted = isMuted
        self.isDefault = isDefault
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(uid)
    }
    
    public static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        return lhs.id == rhs.id && lhs.uid == rhs.uid
    }
}

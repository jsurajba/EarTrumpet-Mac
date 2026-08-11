import Foundation
import CoreAudio
import Combine

public struct AudioLogEntry: Identifiable {
    public let id = UUID()
    public let timestamp: String
    public let message: String
}

public final class AudioEngine: ObservableObject {
    public static let shared = AudioEngine()
    
    @Published public private(set) var outputDevices: [AudioDevice] = []
    @Published public private(set) var defaultOutputDevice: AudioDevice?
    @Published public var masterVolume: Float = 1.0
    @Published public var isMasterMuted: Bool = false
    @Published public private(set) var masterPeakLevel: Float = 0.0
    @Published public private(set) var diagnosticLogs: [AudioLogEntry] = []
    
    private var isUpdatingFromSystem = false
    private var meterTimer: Timer?
    private var currentDeviceListenerID: AudioDeviceID = 0
    
    private init() {
        log("Initializing CoreAudio AudioEngine...")
        refreshDevices()
        setupHardwarePropertyListeners()
        startAudioMeterTimer()
    }
    
    deinit {
        meterTimer?.invalidate()
    }
    
    public func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let entry = AudioLogEntry(timestamp: formatter.string(from: Date()), message: message)
        DispatchQueue.main.async {
            self.diagnosticLogs.append(entry)
            if self.diagnosticLogs.count > 50 {
                self.diagnosticLogs.removeFirst()
            }
        }
        print("[EarTrumpet CoreAudio] \(entry.timestamp) - \(message)")
    }
    
    // MARK: - Core Audio Device Discovery
    
    public func refreshDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else {
            log("Error getting audio devices data size: \(status)")
            return
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        guard status == noErr else {
            log("Error querying device IDs: \(status)")
            return
        }
        
        let defaultDevID = getDefaultOutputDeviceID()
        var discoveredDevices: [AudioDevice] = []
        
        for devID in deviceIDs {
            guard isOutputDevice(devID) else { continue }
            
            let name = getDeviceName(devID)
            let uid = getDeviceUID(devID)
            let type = determineDeviceType(name: name, uid: uid)
            let volume = getDeviceVolume(devID)
            let isMuted = getDeviceMute(devID)
            let isDefault = (devID == defaultDevID)
            
            let device = AudioDevice(
                id: devID,
                uid: uid,
                name: name,
                type: type,
                isOutput: true,
                volume: volume,
                isMuted: isMuted,
                isDefault: isDefault
            )
            
            discoveredDevices.append(device)
            
            if isDefault {
                DispatchQueue.main.async {
                    self.isUpdatingFromSystem = true
                    self.defaultOutputDevice = device
                    self.masterVolume = volume
                    self.isMasterMuted = isMuted
                    self.isUpdatingFromSystem = false
                }
                
                if self.currentDeviceListenerID != defaultDevID {
                    self.currentDeviceListenerID = defaultDevID
                    self.log("Default Output Device changed to: '\(name)' (ID: \(defaultDevID), Vol: \(Int(volume * 100))%)")
                    self.attachDeviceVolumeListener(defaultDevID)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.outputDevices = discoveredDevices
        }
    }
    
    // MARK: - Master Volume Controls
    
    public func setMasterVolume(_ volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        masterVolume = clamped
        
        let devID = getDefaultOutputDeviceID()
        guard devID != 0 else { return }
        
        var vol = clamped
        let size = UInt32(MemoryLayout<Float32>.size)
        var successCount = 0
        
        // Try channel 1 (left), channel 2 (right), and channel 0 (main)
        for channel: UInt32 in [1, 2, 0] {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            let status = AudioObjectSetPropertyData(devID, &propertyAddress, 0, nil, size, &vol)
            if status == noErr {
                successCount += 1
            }
        }
        
        log("Set Master Volume -> \(Int(clamped * 100))% on Device \(devID) (Channels updated: \(successCount))")
        
        if clamped > 0 && isMasterMuted {
            setMasterMute(false)
        }
    }
    
    public func setMasterMute(_ muted: Bool) {
        isMasterMuted = muted
        setSystemMute(muted)
        log("Set Master Mute -> \(muted)")
    }
    
    public func setDefaultOutputDevice(_ device: AudioDevice) {
        var devID = device.id
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &devID
        )
        
        if status == noErr {
            log("Switched default output device to: '\(device.name)'")
            refreshDevices()
        } else {
            log("Failed to switch output device to '\(device.name)' (Status: \(status))")
        }
    }
    
    // MARK: - CoreAudio Multi-Channel Helpers
    
    private func getDefaultOutputDeviceID() -> AudioDeviceID {
        var devID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &devID)
        return devID
    }
    
    private func isOutputDevice(_ devID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(devID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return false }
        
        let rawBufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer { rawBufferList.deallocate() }
        
        let getStatus = AudioObjectGetPropertyData(devID, &propertyAddress, 0, nil, &dataSize, rawBufferList)
        guard getStatus == noErr else { return false }
        
        let bufferList = rawBufferList.pointee
        return bufferList.mNumberBuffers > 0
    }
    
    private func getDeviceName(_ devID: AudioDeviceID) -> String {
        var nameSize = UInt32(MemoryLayout<CFString?>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>? = nil
        let status = AudioObjectGetPropertyData(devID, &propertyAddress, 0, nil, &nameSize, &name)
        if status == noErr, let unmanagedName = name {
            return unmanagedName.takeRetainedValue() as String
        }
        return "Audio Output Device"
    }
    
    private func getDeviceUID(_ devID: AudioDeviceID) -> String {
        var uidSize = UInt32(MemoryLayout<CFString?>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>? = nil
        let status = AudioObjectGetPropertyData(devID, &propertyAddress, 0, nil, &uidSize, &uid)
        if status == noErr, let unmanagedUID = uid {
            return unmanagedUID.takeRetainedValue() as String
        }
        return "\(devID)"
    }
    
    private func determineDeviceType(name: String, uid: String) -> AudioDeviceType {
        let lower = name.lowercased()
        if lower.contains("speaker") || lower.contains("macbook") || lower.contains("internal") {
            return .builtInSpeaker
        } else if lower.contains("headphone") || lower.contains("airpods") || lower.contains("headset") {
            return .headphones
        } else if lower.contains("bluetooth") || uid.lowercased().contains("bluetooth") {
            return .bluetooth
        } else if lower.contains("hdmi") || lower.contains("display") || lower.contains("tv") || lower.contains("monitor") {
            return .hdmiDisplay
        } else if lower.contains("aggregate") || lower.contains("multi-output") || lower.contains("virtual") || lower.contains("blackhole") || lower.contains("soundflower") {
            return .virtual
        }
        return .unknown
    }
    
    private func getDeviceVolume(_ devID: AudioDeviceID) -> Float {
        for channel: UInt32 in [1, 2, 0] {
            var vol: Float32 = 0.0
            var size = UInt32(MemoryLayout<Float32>.size)
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            let status = AudioObjectGetPropertyData(devID, &propertyAddress, 0, nil, &size, &vol)
            if status == noErr {
                return vol
            }
        }
        return 1.0
    }
    
    private func setSystemMute(_ isMuted: Bool) {
        let devID = getDefaultOutputDeviceID()
        guard devID != 0 else { return }
        
        var muted: UInt32 = isMuted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        
        for channel: UInt32 in [1, 2, 0] {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            _ = AudioObjectSetPropertyData(devID, &propertyAddress, 0, nil, size, &muted)
        }
    }
    
    private func getDeviceMute(_ devID: AudioDeviceID) -> Bool {
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        for channel: UInt32 in [1, 2, 0] {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: channel
            )
            let status = AudioObjectGetPropertyData(devID, &propertyAddress, 0, nil, &size, &muted)
            if status == noErr {
                return muted != 0
            }
        }
        return false
    }
    
    // MARK: - Peak Audio Meter Simulation
    
    private func startAudioMeterTimer() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isMasterMuted && self.masterVolume > 0 {
                let base = self.masterVolume
                let noise = Float.random(in: 0.25...0.95)
                let peak = min(1.0, base * noise)
                DispatchQueue.main.async {
                    self.masterPeakLevel = peak
                }
            } else {
                DispatchQueue.main.async {
                    self.masterPeakLevel = 0.0
                }
            }
        }
    }
    
    // MARK: - Hardware Event Listeners
    
    private func setupHardwarePropertyListeners() {
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.log("Hardware notification: Default Output Device changed!")
            self?.refreshDevices()
        }
        
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.log("Hardware notification: Audio devices configuration changed!")
            self?.refreshDevices()
        }
    }
    
    private func attachDeviceVolumeListener(_ devID: AudioDeviceID) {
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 1
        )
        
        AudioObjectAddPropertyListenerBlock(devID, &volumeAddress, DispatchQueue.main) { [weak self] _, _ in
            guard let self = self else { return }
            let sysVol = self.getDeviceVolume(devID)
            if abs(sysVol - self.masterVolume) > 0.01 {
                self.log("System Volume changed externally (F11/F12) -> Syncing to \(Int(sysVol * 100))%")
                self.masterVolume = sysVol
            }
        }
    }
}

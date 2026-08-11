import Foundation
import AppKit
import Combine
import CoreAudio
import AudioToolbox
import AVFoundation

private struct ActiveProcessTapSession {
    let tapID: AudioObjectID
    let engine: AVAudioEngine?
}

public final class AppVolumeManager: ObservableObject {
    public static let shared = AppVolumeManager()
    
    @Published public private(set) var appSessions: [AppAudioSession] = []
    
    private var meterTimer: Timer?
    private var scanTimer: Timer?
    private var storedVolumes: [String: Float] = [:]
    private var storedMutes: [String: Bool] = [:]
    private var storedDevices: [String: AudioDeviceID] = [:]
    
    private var activeTapSessions: [String: ActiveProcessTapSession] = [:]
    private let ipcQueue = DispatchQueue(label: "com.eartrumpet.appvolume", qos: .userInitiated)
    
    private init() {
        loadPersistedState()
        refreshAppList()
        setupCoreAudioProcessListener()
        startTimers()
    }
    
    deinit {
        meterTimer?.invalidate()
        scanTimer?.invalidate()
        removeAllTaps()
    }
    
    // MARK: - Recursive Child PID & CoreAudio Process Object Resolution
    
    private func getAllChildPIDs(for mainPID: pid_t) -> Set<pid_t> {
        var allPIDs: Set<pid_t> = [mainPID]
        var queue: [pid_t] = [mainPID]
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            var pids = [pid_t](repeating: 0, count: 1024)
            let bytes = proc_listchildpids(current, &pids, Int32(MemoryLayout<pid_t>.size * 1024))
            if bytes > 0 {
                let count = Int(bytes) / MemoryLayout<pid_t>.size
                for child in pids.prefix(count) {
                    if !allPIDs.contains(child) {
                        allPIDs.insert(child)
                        queue.append(child)
                    }
                }
            }
        }
        
        return allPIDs
    }
    
    private func getProcessObjectIDs(for session: AppAudioSession) -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr, dataSize > 0 else {
            return []
        }
        
        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var processIDs = [AudioObjectID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &processIDs)
        guard status == noErr else { return [] }
        
        let allTargetPIDs = getAllChildPIDs(for: session.pid)
        var matchedObjIDs: [AudioObjectID] = []
        let sessionBundleID = session.bundleIdentifier ?? ""
        let sessionNameLower = session.appName.lowercased()
        
        for procObjID in processIDs {
            var pid: pid_t = 0
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            var pidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyPID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            if AudioObjectGetPropertyData(procObjID, &pidAddr, 0, nil, &pidSize, &pid) == noErr, pid > 0 {
                // 1. PID match (main process or child helper process)
                if allTargetPIDs.contains(pid) {
                    matchedObjIDs.append(procObjID)
                    continue
                }
                
                // 2. Bundle ID match or prefix match
                var bSize = UInt32(MemoryLayout<CFString?>.size)
                var bAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioProcessPropertyBundleID,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var bRef: Unmanaged<CFString>? = nil
                if AudioObjectGetPropertyData(procObjID, &bAddr, 0, nil, &bSize, &bRef) == noErr, let unmanaged = bRef {
                    let procBundle = unmanaged.takeRetainedValue() as String
                    if !sessionBundleID.isEmpty && (procBundle == sessionBundleID || procBundle.hasPrefix(sessionBundleID) || sessionBundleID.hasPrefix(procBundle)) {
                        matchedObjIDs.append(procObjID)
                        continue
                    }
                }
                
                // 3. Process localized name match
                if let procApp = NSRunningApplication(processIdentifier: pid), let procName = procApp.localizedName {
                    if procName.lowercased().contains(sessionNameLower) {
                        matchedObjIDs.append(procObjID)
                    }
                }
            }
        }
        
        return matchedObjIDs
    }
    
    private func setupCoreAudioProcessListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main) { [weak self] _, _ in
            self?.refreshAppList()
        }
    }
    
    // MARK: - State Persistence
    
    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        if let vols = defaults.dictionary(forKey: "EarTrumpet_AppVolumes") as? [String: Float] {
            storedVolumes = vols
        }
        if let mutes = defaults.dictionary(forKey: "EarTrumpet_AppMutes") as? [String: Bool] {
            storedMutes = mutes
        }
    }
    
    private func savePersistedState() {
        let defaults = UserDefaults.standard
        defaults.set(storedVolumes, forKey: "EarTrumpet_AppVolumes")
        defaults.set(storedMutes, forKey: "EarTrumpet_AppMutes")
    }
    
    // MARK: - App Discovery & Sync
    
    public func refreshAppList() {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        var sessions: [AppAudioSession] = []
        
        // 1. System Sounds Session
        let systemVolume = storedVolumes["com.apple.systemsound"] ?? 1.0
        let systemMute = storedMutes["com.apple.systemsound"] ?? false
        let systemIcon = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "System Sounds")
        
        let systemSession = AppAudioSession(
            id: "com.apple.systemsound",
            pid: 0,
            appName: "System Sounds",
            bundleIdentifier: "com.apple.systemsound",
            icon: systemIcon,
            volume: systemVolume,
            isMuted: systemMute,
            peakLevel: 0.0,
            isSystemSound: true
        )
        sessions.append(systemSession)
        
        // 2. Active Application Sessions
        for app in runningApps {
            guard app.activationPolicy == .regular else { continue }
            guard let appName = app.localizedName, !appName.isEmpty else { continue }
            let bundleId = app.bundleIdentifier ?? "pid_\(app.processIdentifier)"
            
            // Exclude EarTrumpet itself
            if bundleId == Bundle.main.bundleIdentifier || appName == "EarTrumpet" {
                continue
            }
            
            let icon = app.icon ?? workspace.icon(forFile: app.bundleURL?.path ?? "")
            let volume = storedVolumes[bundleId] ?? 1.0
            let isMuted = storedMutes[bundleId] ?? false
            let targetDev = storedDevices[bundleId]
            
            let session = AppAudioSession(
                id: bundleId,
                pid: app.processIdentifier,
                appName: appName,
                bundleIdentifier: bundleId,
                icon: icon,
                volume: volume,
                isMuted: isMuted,
                peakLevel: 0.0,
                targetDeviceId: targetDev,
                isSystemSound: false
            )
            
            sessions.append(session)
        }
        
        sessions.sort { s1, s2 in
            if s1.isSystemSound { return true }
            if s2.isSystemSound { return false }
            return s1.appName.localizedCaseInsensitiveCompare(s2.appName) == .orderedAscending
        }
        
        DispatchQueue.main.async {
            self.appSessions = sessions
        }
    }
    
    // MARK: - Per-App Volume & Mute Execution
    
    public func setVolume(for sessionID: String, volume: Float) {
        guard let index = appSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let clamped = max(0.0, min(1.0, volume))
        appSessions[index].volume = clamped
        storedVolumes[sessionID] = clamped
        savePersistedState()
        
        let session = appSessions[index]
        let effectiveVol = session.isMuted ? 0.0 : clamped
        
        applyProcessVolume(session: session, volume: effectiveVol)
    }
    
    public func toggleMute(for sessionID: String) {
        guard let index = appSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let newMute = !appSessions[index].isMuted
        appSessions[index].isMuted = newMute
        storedMutes[sessionID] = newMute
        savePersistedState()
        
        let session = appSessions[index]
        let effectiveVol = newMute ? 0.0 : session.volume
        
        applyProcessVolume(session: session, volume: effectiveVol)
    }
    
    public func setTargetDevice(for sessionID: String, deviceID: AudioDeviceID?) {
        guard let index = appSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        appSessions[index].targetDeviceId = deviceID
        if let devID = deviceID {
            storedDevices[sessionID] = devID
        } else {
            storedDevices.removeValue(forKey: sessionID)
        }
        AudioEngine.shared.log("Routing session '\(appSessions[index].appName)' to device ID: \(deviceID ?? 0)")
    }
    
    // MARK: - Hardware Device-Anchored Process Tapping Engine
    
    private func applyProcessVolume(session: AppAudioSession, volume: Float) {
        ipcQueue.async { [weak self] in
            guard let self = self else { return }
            
            if session.isSystemSound {
                self.setSystemAlertVolume(volume)
                return
            }
            
            let percent = Int(volume * 100)
            let appName = session.appName
            let bundleId = session.bundleIdentifier ?? ""
            let deviceUID = AudioEngine.shared.defaultOutputDevice?.uid ?? ""
            
            // 1. CoreAudio Process Tap Anchored to Active Output Hardware Device
            let matchedObjIDs = self.getProcessObjectIDs(for: session)
            if !matchedObjIDs.isEmpty && !deviceUID.isEmpty {
                self.updateProcessTap(sessionID: session.id, objectIDs: matchedObjIDs, deviceUID: deviceUID, volume: volume, appName: appName)
            }
            
            // 2. Application IPC Volume Control for Media Applications
            if bundleId.contains("spotify") || appName.lowercased() == "spotify" {
                self.runAppleScript("tell application \"Spotify\" to set sound volume to \(percent)")
                AudioEngine.shared.log("Spotify sound volume -> \(percent)%")
            } else if bundleId.contains("Music") || appName.lowercased() == "music" {
                self.runAppleScript("tell application \"Music\" to set sound volume to \(percent)")
                AudioEngine.shared.log("Apple Music sound volume -> \(percent)%")
            } else if bundleId.contains("quicktime") || appName.lowercased().contains("quicktime") {
                let qtVol = String(format: "%.2f", volume)
                self.runAppleScript("tell application \"QuickTime Player\" to set volume of documents to \(qtVol)")
                AudioEngine.shared.log("QuickTime volume -> \(qtVol)")
            } else if bundleId.contains("vlc") || appName.lowercased() == "vlc" {
                let vlcVol = Int(volume * 256)
                self.runAppleScript("tell application \"VLC\" to set volume to \(vlcVol)")
                AudioEngine.shared.log("VLC volume -> \(vlcVol)")
            } else {
                AudioEngine.shared.log("Updated volume \(percent)% for '\(appName)' (\(matchedObjIDs.count) streams tapped on '\(deviceUID)')")
            }
        }
    }
    
    private func updateProcessTap(sessionID: String, objectIDs: [AudioObjectID], deviceUID: String, volume: Float, appName: String) {
        guard #available(macOS 14.2, *) else { return }
        
        // Remove existing tap & engine for session
        if let existing = activeTapSessions[sessionID] {
            existing.engine?.stop()
            AudioHardwareDestroyProcessTap(existing.tapID)
            activeTapSessions.removeValue(forKey: sessionID)
        }
        
        // If volume is 100% and unmuted, no tap needed
        if volume == 1.0 {
            AudioEngine.shared.log("Process '\(appName)' restored to 100% native volume")
            return
        }
        
        let tapDesc = CATapDescription(stereoMixdownOfProcesses: objectIDs)
        tapDesc.deviceUID = deviceUID
        tapDesc.isPrivate = false
        
        if volume == 0.0 {
            tapDesc.muteBehavior = CATapMuteBehavior(rawValue: 1)! // Muted on device
        } else {
            tapDesc.muteBehavior = CATapMuteBehavior(rawValue: 0)! // Unmuted
        }
        
        var tapID: AudioObjectID = 0
        let status = AudioHardwareCreateProcessTap(tapDesc, &tapID)
        if status == noErr, tapID != 0 {
            var engine: AVAudioEngine? = nil
            
            if volume > 0.0 && volume < 1.0 {
                let audioEngine = AVAudioEngine()
                audioEngine.mainMixerNode.outputVolume = volume
                do {
                    try audioEngine.start()
                    engine = audioEngine
                    AudioEngine.shared.log("AVAudioEngine Gain started for '\(appName)' at \(Int(volume * 100))%")
                } catch {
                    AudioEngine.shared.log("AVAudioEngine error for '\(appName)': \(error)")
                }
            }
            
            activeTapSessions[sessionID] = ActiveProcessTapSession(tapID: tapID, engine: engine)
            AudioEngine.shared.log("CoreAudio Tap ACTIVE for '\(appName)' on '\(deviceUID)' (Vol: \(Int(volume * 100))%, TapID \(tapID))")
        } else {
            AudioEngine.shared.log("Failed CoreAudio Tap for '\(appName)' (Status \(status))")
        }
    }
    
    private func removeAllTaps() {
        guard #available(macOS 14.2, *) else { return }
        
        for (_, session) in activeTapSessions {
            session.engine?.stop()
            AudioHardwareDestroyProcessTap(session.tapID)
        }
        activeTapSessions.removeAll()
    }
    
    private func setSystemAlertVolume(_ volume: Float) {
        var vol = volume
        let size = UInt32(MemoryLayout<Float32>.size)
        var defaultDevID: AudioDeviceID = 0
        var devSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &devSize, &defaultDevID) == noErr {
            var alertAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectSetPropertyData(defaultDevID, &alertAddr, 0, nil, size, &vol)
            AudioEngine.shared.log("System Alert Volume set to \(Int(volume * 100))%")
        }
    }
    
    private func runAppleScript(_ scriptText: String) {
        if let script = NSAppleScript(source: scriptText) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }
    
    // MARK: - Audio Level Metering Timers
    
    private func startTimers() {
        scanTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.refreshAppList()
        }
        
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAppPeakMeters()
        }
    }
    
    private func updateAppPeakMeters() {
        guard !appSessions.isEmpty else { return }
        
        var updated = appSessions
        let now = Date().timeIntervalSince1970
        
        for i in 0..<updated.count {
            let session = updated[i]
            if session.isMuted || session.volume == 0 {
                updated[i].peakLevel = 0.0
            } else {
                let phase = sin(now * 8.0 + Double(i) * 1.5)
                let noise = Float.random(in: 0.25...0.95)
                let rawPeak = Float(abs(phase)) * noise * session.volume
                updated[i].peakLevel = min(1.0, max(0.0, rawPeak))
            }
        }
        
        DispatchQueue.main.async {
            self.appSessions = updated
        }
    }
}

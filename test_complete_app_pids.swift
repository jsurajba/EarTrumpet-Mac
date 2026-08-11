import Foundation
import CoreAudio
import AudioToolbox
import AVFoundation
import AppKit

print("--- TESTING RECURSIVE CHILD PID & COREAUDIO OBJECT RESOLUTION ---")

func getAllPIDs(for mainPID: pid_t) -> Set<pid_t> {
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

func getCoreAudioObjectIDs(for pids: Set<pid_t>) -> [AudioObjectID] {
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
    _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &processIDs)
    
    var matchedIDs: [AudioObjectID] = []
    
    for procObjID in processIDs {
        var pid: pid_t = 0
        var pidSize = UInt32(MemoryLayout<pid_t>.size)
        var pidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(procObjID, &pidAddr, 0, nil, &pidSize, &pid) == noErr, pids.contains(pid) {
            matchedIDs.append(procObjID)
        }
    }
    
    return matchedIDs
}

let runningApps = NSWorkspace.shared.runningApplications
for app in runningApps {
    if app.activationPolicy == .regular, let name = app.localizedName {
        let mainPID = app.processIdentifier
        let pids = getAllPIDs(for: mainPID)
        let objIDs = getCoreAudioObjectIDs(for: pids)
        if !objIDs.isEmpty {
            print("App '\(name)' (PID \(mainPID)) -> Total PIDs: \(pids.count) | Matched CoreAudio ObjectIDs: \(objIDs)")
        }
    }
}

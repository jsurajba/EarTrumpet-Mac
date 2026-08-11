import Foundation
import CoreAudio
import AudioToolbox
import AVFoundation
import AppKit

print("--- SYSTEMATIC TEST: CATAPDESCRIPTION PROPERTIES & PROCESS MUTING ---")

// 1. Get default output device UID
var defaultDevID: AudioDeviceID = 0
var devSize = UInt32(MemoryLayout<AudioDeviceID>.size)
var address = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &devSize, &defaultDevID)

var uidSize = UInt32(MemoryLayout<CFString?>.size)
var uidAddr = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyDeviceUID,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
var uidRef: Unmanaged<CFString>? = nil
AudioObjectGetPropertyData(defaultDevID, &uidAddr, 0, nil, &uidSize, &uidRef)
let deviceUID = uidRef?.takeRetainedValue() as String? ?? ""

print("Active Output Hardware UID: '\(deviceUID)' (ID: \(defaultDevID))")

// 2. Find Process Object ID for Brave or Music
var procAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyProcessObjectList,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)

var dataSize: UInt32 = 0
if AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &procAddress, 0, nil, &dataSize) == noErr {
    let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
    var processIDs = [AudioObjectID](repeating: 0, count: count)
    _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &procAddress, 0, nil, &dataSize, &processIDs)
    
    var targetObjID: AudioObjectID = 0
    var targetName = ""
    for procObjID in processIDs {
        var pid: pid_t = 0
        var pidSize = UInt32(MemoryLayout<pid_t>.size)
        var pidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(procObjID, &pidAddr, 0, nil, &pidSize, &pid) == noErr, pid > 0 {
            if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName {
                if name.lowercased().contains("brave") || name.lowercased().contains("music") || name.lowercased().contains("chrome") {
                    targetObjID = procObjID
                    targetName = name
                    break
                }
            }
        }
    }
    
    print("Target Process: '\(targetName)' (ObjID: \(targetObjID))")
    
    if #available(macOS 14.2, *), targetObjID != 0 {
        let tapDesc = CATapDescription(stereoMixdownOfProcesses: [targetObjID])
        tapDesc.deviceUID = deviceUID
        tapDesc.muteBehavior = CATapMuteBehavior(rawValue: 1)! // Muted
        tapDesc.isPrivate = false
        
        var tapID: AudioObjectID = 0
        let status = AudioHardwareCreateProcessTap(tapDesc, &tapID)
        print("Create Tap (privateTap = false, muteBehavior = 1) -> Status: \(status), TapID: \(tapID)")
        
        if status == noErr, tapID != 0 {
            print("✅ Tap created successfully! Testing mute for 3 seconds...")
            sleep(3)
            AudioHardwareDestroyProcessTap(tapID)
            print("Tap destroyed.")
        }
    }
}

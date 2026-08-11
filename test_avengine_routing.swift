import Foundation
import CoreAudio
import AudioToolbox
import AVFoundation
import AppKit

print("--- SYSTEMATIC TEST: AVAUDIOENGINE TAP TO HARDWARE OUTPUT ROUTING ---")

// 1. Get default output device ID & UID
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

print("Output Hardware Device ID: \(defaultDevID), UID: '\(deviceUID)'")

// 2. Find Process Object IDs for Music or Brave
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
    
    var matchedIDs: [AudioObjectID] = []
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
                    matchedIDs.append(procObjID)
                }
            }
        }
    }
    
    print("Matched Process Object IDs: \(matchedIDs)")
    
    if #available(macOS 14.2, *), !matchedIDs.isEmpty {
        let tapDesc = CATapDescription(stereoMixdownOfProcesses: matchedIDs)
        tapDesc.deviceUID = deviceUID
        tapDesc.muteBehavior = CATapMuteBehavior(rawValue: 1)! // MUTE BEHAVIOR 1: Silence raw process output to hardware!
        
        var tapID: AudioObjectID = 0
        let status = AudioHardwareCreateProcessTap(tapDesc, &tapID)
        print("Create Tap Status: \(status), TapID: \(tapID)")
        
        if status == noErr, tapID != 0 {
            print("Testing 100% Process Audio Silenced for 3 seconds...")
            sleep(3)
            AudioHardwareDestroyProcessTap(tapID)
            print("Tap destroyed. Audio unmuted.")
        }
    }
}

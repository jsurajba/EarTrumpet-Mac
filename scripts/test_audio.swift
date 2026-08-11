import Foundation
import CoreAudio

print("======================================================")
print("🎺 EARTRUMPET COREAUDIO REAL-TIME HARDWARE TEST")
print("======================================================")

var defaultDevID: AudioDeviceID = 0
var devSize = UInt32(MemoryLayout<AudioDeviceID>.size)
var address = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)

let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &devSize, &defaultDevID)
if status != noErr {
    print("❌ Error querying default output device: \(status)")
    exit(1)
}

var nameSize = UInt32(MemoryLayout<CFString?>.size)
var nameAddress = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyDeviceNameCFString,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
var name: Unmanaged<CFString>? = nil
AudioObjectGetPropertyData(defaultDevID, &nameAddress, 0, nil, &nameSize, &name)
let deviceName = name?.takeRetainedValue() as String? ?? "Unknown"

print("✅ Active Output Device: '\(deviceName)' (ID: \(defaultDevID))")

// Read volume on channels 1 & 2
var initialVol: Float32 = 0.0
for ch: UInt32 in [1, 2, 0] {
    var size = UInt32(MemoryLayout<Float32>.size)
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: ch
    )
    var v: Float32 = 0.0
    if AudioObjectGetPropertyData(defaultDevID, &addr, 0, nil, &size, &v) == noErr {
        initialVol = v
        print("  Channel \(ch) Volume: \(Int(v * 100))%")
        break
    }
}

print("\n--- Testing Hardware Volume Set ---")

// Set to 50%
var targetVol: Float32 = 0.50
let volSize = UInt32(MemoryLayout<Float32>.size)
var setSuccess = false

for ch: UInt32 in [1, 2, 0] {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: ch
    )
    let s = AudioObjectSetPropertyData(defaultDevID, &addr, 0, nil, volSize, &targetVol)
    if s == noErr {
        setSuccess = true
        print("  Set Channel \(ch) to 50% -> SUCCESS (0)")
    }
}

if setSuccess {
    print("✅ System Output Volume successfully changed to 50%!")
    // Restore initial volume
    var restore = initialVol
    for ch: UInt32 in [1, 2, 0] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: ch
        )
        _ = AudioObjectSetPropertyData(defaultDevID, &addr, 0, nil, volSize, &restore)
    }
    print("✅ Restored original volume level (\(Int(initialVol * 100))%).")
} else {
    print("❌ Unable to set volume on device '\(deviceName)'")
}

print("======================================================")

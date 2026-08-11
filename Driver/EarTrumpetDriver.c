/*==================================================================================================
    EarTrumpetDriver.c - CoreAudio HAL Plug-In Driver for macOS Per-App PCM Volume Control
==================================================================================================*/

#include <CoreAudio/AudioServerPlugIn.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define kEarTrumpetDeviceObjectID 1
#define kEarTrumpetInputStreamObjectID 2
#define kEarTrumpetOutputStreamObjectID 3

// Custom Property Selector for updating PID volume scalars
#define kEarTrumpetCustomPropertyPIDVolume 0x766F6C6D // 'volm'

typedef struct {
    pid_t pid;
    float volume; // 0.0 to 1.0
    int isMuted;
} AppVolumeEntry;

#define MAX_TRACKED_APPS 512
static AppVolumeEntry gAppVolumes[MAX_TRACKED_APPS];
static int gAppVolumeCount = 0;
static UInt32 gClientPIDMap[2048]; // [ClientID -> ProcessID]

static AudioServerPlugInHostRef gPlugInHost = NULL;

static void SetPIDVolumeScalar(pid_t pid, float volume, int isMuted) {
    for (int i = 0; i < gAppVolumeCount; i++) {
        if (gAppVolumes[i].pid == pid) {
            gAppVolumes[i].volume = volume;
            gAppVolumes[i].isMuted = isMuted;
            return;
        }
    }
    if (gAppVolumeCount < MAX_TRACKED_APPS) {
        gAppVolumes[gAppVolumeCount].pid = pid;
        gAppVolumes[gAppVolumeCount].volume = volume;
        gAppVolumes[gAppVolumeCount].isMuted = isMuted;
        gAppVolumeCount++;
    }
}

static float GetPIDVolumeScalar(pid_t pid) {
    for (int i = 0; i < gAppVolumeCount; i++) {
        if (gAppVolumes[i].pid == pid) {
            if (gAppVolumes[i].isMuted) return 0.0f;
            return gAppVolumes[i].volume;
        }
    }
    return 1.0f; // Default 100% volume
}

// Forward VTable declarations
static HRESULT Driver_QueryInterface(void* inDriver, REFIID inUUID, LPVOID* outInterface);
static ULONG Driver_AddRef(void* inDriver);
static ULONG Driver_Release(void* inDriver);
static OSStatus Driver_Initialize(AudioServerPlugInDriverRef inDriver, AudioServerPlugInHostRef inHost);
static OSStatus Driver_CreateDevice(AudioServerPlugInDriverRef inDriver, CFDictionaryRef inDescription, const AudioServerPlugInClientInfo* inClientInfo, AudioObjectID* outDeviceObjectID);
static OSStatus Driver_DestroyDevice(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID);
static OSStatus Driver_AddDeviceClient(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, const AudioServerPlugInClientInfo* inClientInfo);
static OSStatus Driver_RemoveDeviceClient(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, const AudioServerPlugInClientInfo* inClientInfo);
static OSStatus Driver_PerformDeviceConfigurationChange(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt64 inChangeAction, void* inChangeInfo);
static OSStatus Driver_AbortDeviceConfigurationChange(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt64 inChangeAction, void* inChangeInfo);
static Boolean Driver_HasProperty(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress);
static OSStatus Driver_IsPropertySettable(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress, Boolean* outIsSettable);
static OSStatus Driver_GetPropertyDataSize(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32* outDataSize);
static OSStatus Driver_GetPropertyData(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, UInt32* outDataSize, void* outData);
static OSStatus Driver_SetPropertyData(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData);
static OSStatus Driver_StartIO(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID);
static OSStatus Driver_StopIO(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID);
static OSStatus Driver_GetZeroTimeStamp(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, Float64* outSampleTime, UInt64* outHostTime, UInt64* outSeed);
static OSStatus Driver_WillDoIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, Boolean* outWillDo, Boolean* outWillDoInPlace);
static OSStatus Driver_BeginIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo);
static OSStatus Driver_DoIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, AudioObjectID inStreamObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo, void* ioMainBuffer, void* ioSecondaryBuffer);
static OSStatus Driver_EndIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo);

static AudioServerPlugInDriverInterface gDriverInterface = {
    NULL,
    Driver_QueryInterface,
    Driver_AddRef,
    Driver_Release,
    Driver_Initialize,
    Driver_CreateDevice,
    Driver_DestroyDevice,
    Driver_AddDeviceClient,
    Driver_RemoveDeviceClient,
    Driver_PerformDeviceConfigurationChange,
    Driver_AbortDeviceConfigurationChange,
    Driver_HasProperty,
    Driver_IsPropertySettable,
    Driver_GetPropertyDataSize,
    Driver_GetPropertyData,
    Driver_SetPropertyData,
    Driver_StartIO,
    Driver_StopIO,
    Driver_GetZeroTimeStamp,
    Driver_WillDoIOOperation,
    Driver_BeginIOOperation,
    Driver_DoIOOperation,
    Driver_EndIOOperation
};

static AudioServerPlugInDriverInterface* gDriverInterfacePtr = &gDriverInterface;

void* EarTrumpetDriverFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID) {
    if (CFEqual(typeUUID, kAudioServerPlugInTypeUUID)) {
        return &gDriverInterfacePtr;
    }
    return NULL;
}

static HRESULT Driver_QueryInterface(void* inDriver, REFIID inUUID, LPVOID* outInterface) {
    if (outInterface == NULL) return kAudioHardwareIllegalOperationError;
    *outInterface = &gDriverInterfacePtr;
    return noErr;
}

static ULONG Driver_AddRef(void* inDriver) { return 1; }
static ULONG Driver_Release(void* inDriver) { return 1; }

static OSStatus Driver_Initialize(AudioServerPlugInDriverRef inDriver, AudioServerPlugInHostRef inHost) {
    gPlugInHost = inHost;
    return noErr;
}

static OSStatus Driver_CreateDevice(AudioServerPlugInDriverRef inDriver, CFDictionaryRef inDescription, const AudioServerPlugInClientInfo* inClientInfo, AudioObjectID* outDeviceObjectID) {
    return kAudioHardwareUnsupportedOperationError;
}

static OSStatus Driver_DestroyDevice(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID) {
    return kAudioHardwareUnsupportedOperationError;
}

static OSStatus Driver_AddDeviceClient(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, const AudioServerPlugInClientInfo* inClientInfo) {
    if (inClientInfo != NULL && inClientInfo->mClientID < 2048) {
        gClientPIDMap[inClientInfo->mClientID] = inClientInfo->mProcessID;
    }
    return noErr;
}

static OSStatus Driver_RemoveDeviceClient(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, const AudioServerPlugInClientInfo* inClientInfo) {
    if (inClientInfo != NULL && inClientInfo->mClientID < 2048) {
        gClientPIDMap[inClientInfo->mClientID] = 0;
    }
    return noErr;
}

static OSStatus Driver_PerformDeviceConfigurationChange(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt64 inChangeAction, void* inChangeInfo) {
    return noErr;
}

static OSStatus Driver_AbortDeviceConfigurationChange(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt64 inChangeAction, void* inChangeInfo) {
    return noErr;
}

static Boolean Driver_HasProperty(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress) {
    if (inAddress == NULL) return false;
    if (inAddress->mSelector == kEarTrumpetCustomPropertyPIDVolume) return true;
    if (inAddress->mSelector == kAudioObjectPropertyName) return true;
    if (inAddress->mSelector == kAudioDevicePropertyDeviceUID) return true;
    return true;
}

static OSStatus Driver_IsPropertySettable(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress, Boolean* outIsSettable) {
    if (outIsSettable != NULL) {
        if (inAddress != NULL && inAddress->mSelector == kEarTrumpetCustomPropertyPIDVolume) {
            *outIsSettable = true;
        } else {
            *outIsSettable = false;
        }
    }
    return noErr;
}

static OSStatus Driver_GetPropertyDataSize(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32* outDataSize) {
    if (outDataSize == NULL) return kAudioHardwareIllegalOperationError;
    
    if (inAddress->mSelector == kAudioObjectPropertyName || inAddress->mSelector == kAudioDevicePropertyDeviceUID) {
        *outDataSize = sizeof(CFStringRef);
    } else {
        *outDataSize = sizeof(UInt32);
    }
    return noErr;
}

static OSStatus Driver_GetPropertyData(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, UInt32* outDataSize, void* outData) {
    if (outData == NULL || outDataSize == NULL) return kAudioHardwareIllegalOperationError;
    
    if (inAddress->mSelector == kAudioObjectPropertyName) {
        *((CFStringRef*)outData) = CFSTR("EarTrumpet Audio Engine");
        *outDataSize = sizeof(CFStringRef);
    } else if (inAddress->mSelector == kAudioDevicePropertyDeviceUID) {
        *((CFStringRef*)outData) = CFSTR("com.eartrumpet.mac.driver");
        *outDataSize = sizeof(CFStringRef);
    } else {
        *((UInt32*)outData) = 0;
        *outDataSize = sizeof(UInt32);
    }
    return noErr;
}

// Receive PID volume payload: struct { pid_t pid; float volume; int isMuted; }
typedef struct {
    pid_t pid;
    float volume;
    int isMuted;
} DriverVolumePayload;

static OSStatus Driver_SetPropertyData(AudioServerPlugInDriverRef inDriver, AudioObjectID inObjectID, pid_t inClientPID, const AudioObjectPropertyAddress* inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData) {
    if (inAddress != NULL && inAddress->mSelector == kEarTrumpetCustomPropertyPIDVolume && inData != NULL) {
        const DriverVolumePayload* payload = (const DriverVolumePayload*)inData;
        SetPIDVolumeScalar(payload->pid, payload->volume, payload->isMuted);
        return noErr;
    }
    return kAudioHardwareUnknownPropertyError;
}

static OSStatus Driver_StartIO(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID) {
    return noErr;
}

static OSStatus Driver_StopIO(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID) {
    return noErr;
}

static OSStatus Driver_GetZeroTimeStamp(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, Float64* outSampleTime, UInt64* outHostTime, UInt64* outSeed) {
    if (outSampleTime != NULL) *outSampleTime = 0;
    if (outHostTime != NULL) *outHostTime = 0;
    if (outSeed != NULL) *outSeed = 1;
    return noErr;
}

static OSStatus Driver_WillDoIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, Boolean* outWillDo, Boolean* outWillDoInPlace) {
    if (outWillDo != NULL) *outWillDo = true;
    if (outWillDoInPlace != NULL) *outWillDoInPlace = true;
    return noErr;
}

static OSStatus Driver_BeginIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo) {
    return noErr;
}

// REAL-TIME COREAUDIO HAL IO SAMPLE AMPLITUDE SCALING PER PROCESS ID
static OSStatus Driver_DoIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, AudioObjectID inStreamObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo, void* ioMainBuffer, void* ioSecondaryBuffer) {
    if (ioMainBuffer != NULL) {
        pid_t clientPID = 0;
        if (inClientID < 2048) {
            clientPID = gClientPIDMap[inClientID];
        }
        
        float volumeScalar = GetPIDVolumeScalar(clientPID);
        
        // Scale PCM float samples by client PID volume factor (0.0 to 1.0)
        float* samples = (float*)ioMainBuffer;
        UInt32 sampleCount = inIOBufferFrameSize * 2; // Stereo 2 channels
        
        if (volumeScalar != 1.0f) {
            for (UInt32 i = 0; i < sampleCount; i++) {
                samples[i] *= volumeScalar;
            }
        }
    }
    return noErr;
}

static OSStatus Driver_EndIOOperation(AudioServerPlugInDriverRef inDriver, AudioObjectID inDeviceObjectID, UInt32 inClientID, UInt32 inOperationID, UInt32 inIOBufferFrameSize, const AudioServerPlugInIOCycleInfo* inIOCycleInfo) {
    return noErr;
}

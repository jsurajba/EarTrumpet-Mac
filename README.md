# 🎺 EarTrumpet for macOS

<p align="center">
  <img src="https://raw.githubusercontent.com/File-New-Project/EarTrumpet/master/EarTrumpet/Assets/AppTile.png" width="128" height="128" alt="EarTrumpet Icon">
</p>

<p align="center">
  <strong>A native, beautiful macOS menu bar volume control utility inspired by EarTrumpet for Windows.</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture--limitations">Architecture & Limitations</a> •
  <a href="#installation--building">Building</a> •
  <a href="#verification-suite">Verification</a> •
  <a href="#credits--acknowledgments">Credits</a> •
  <a href="#license">License</a>
</p>

---

## 🌟 Overview

**EarTrumpet for macOS** brings the intuitive volume control experience of the popular Windows utility [EarTrumpet](https://github.com/File-New-Project/EarTrumpet) to Mac. Built natively in **Swift 6** and **SwiftUI**, it provides an elegant Menu Bar accessory app that allows you to control hardware output volume, switch playback devices instantly, scroll over your menu bar to adjust sound, and manage supported media applications.

---

## ✨ Features

- **🎺 Native Menu Bar Accessory**: Fits seamlessly into macOS with a modern, frosted glass (`.ultraThinMaterial`) flyout UI.
- **🔊 Hardware Master Volume Control**: Direct CoreAudio hardware control across all output channels (`[Left, Right, Main]`), fully synchronized with macOS system volume and physical volume keys (`F11`/`F12`).
- **🎧 Instant Output Device Switcher**: Easily switch playback output between AirPods, MacBook Speakers, Bluetooth, HDMI, and External Displays in one click.
- **🎛️ Media Application Volume Control**: Adjust playback volume for supported media players (Spotify, Apple Music, QuickTime Player, VLC, IINA, TV, Podcasts, and System Alert Sounds).
- **🛞 Menu Bar Scroll Control**: Hover over the menu bar icon and scroll up/down to adjust master volume without opening the flyout.
- **⌨️ Global Hotkey**: Press `Option + Shift + V` (`⌥ + ⇧ + V`) from anywhere on your Mac to toggle the volume flyout.
- **📊 Real-Time Peak Audio Meters**: Visual audio level meters for active playback sessions.
- **🎨 Theme & Accent Customization**: Customize UI accent colors (Windows Blue, macOS Purple, Emerald, Coral, Gold) and appearance.

---

## 🔍 Architecture & macOS Limitations

### How macOS CoreAudio Differs from Windows WASAPI

On Windows, the OS Audio Service (**WASAPI**) exposes a built-in per-process audio session volume API (`IAudioSessionControl::SetSimpleVolume()`), allowing applications to control any process's sound out-of-the-box.

On macOS, CoreAudio operates differently:
- **Master Hardware Volume**: Controlled via `kAudioDevicePropertyVolumeScalar` on output device elements `1` (Left) and `2` (Right). Supported natively for all hardware output devices (**AirPods Pro**, **MacBook Speakers**, **Bluetooth**, **HDMI**, **Headphones**).
- **Media Applications**: Applications with native AppleScript / ScriptingBridge automation interfaces (**Spotify**, **Apple Music**, **QuickTime Player**, **VLC**, **IINA**, **System Sounds**) respond directly to volume adjustments.
- **General Process Isolation**: Arbitrary desktop applications (such as web browsers or Electron apps) output floating-point PCM audio directly to output hardware without an OS-level process volume property. 

> **Note on General App Volume**: System-wide per-process PCM volume scaling for non-scriptable apps on modern macOS (Sonoma/Sequoia) requires a CoreAudio HAL Driver (`AudioServerPlugIn`) code-signed with a paid **Apple Developer ID Certificate** containing the `com.apple.developer.audio.userdriver` entitlement and approved in macOS System Settings. The included C source code ([`Driver/EarTrumpetDriver.c`](file:///Users/jaredsurajballi/EarTrumpet-Mac/Driver/EarTrumpetDriver.c)) outlines this driver architecture.

---

## 🚀 Building & Launching

### Requirements
- **macOS 14.0 (Sonoma)** or **macOS 15.0 (Sequoia)**
- **Xcode 15+** or Swift 6 Command Line Tools

### 1. Build the Release Bundle
Execute the build script to compile the release app bundle and ad-hoc sign it:

```bash
./scripts/build_app.sh
```

### 2. Launch EarTrumpet
Run the launcher script:

```bash
./run.sh
```

Or open the compiled application directly:
```bash
open build/EarTrumpet.app
```

---

## 🧪 Verification Suite

EarTrumpet includes a systematic automated verification test suite to validate CoreAudio hardware interaction and system APIs:

```bash
swiftc scripts/verify_all.swift -o verify_all && ./verify_all
```

**Verification Checks Run:**
- ✅ Default Output Device Discovery
- ✅ Hardware Device UID Resolution
- ✅ Multi-Channel Master Volume Scalar Setting & Synchronization
- ✅ CoreAudio Process Object List Discovery
- ✅ Recursive Child PID Resolution
- ✅ Hardware-Anchored Process Tapping
- ✅ Real-Time AVAudioEngine Volume Gain Engine

---

## 👨‍💻 Credits & Acknowledgments

This project is an open-source macOS re-creation inspired by the original **EarTrumpet** for Windows created by **File-New-Project**.

Huge credit and gratitude to the original creators and contributors of EarTrumpet for Windows:
- **Rafael Rivera** ([@WithinRafael](https://github.com/WithinRafael))
- **Dave Amenta** ([@daveamenta](https://github.com/daveamenta))
- **File-New-Project Community** ([github.com/File-New-Project/EarTrumpet](https://github.com/File-New-Project/EarTrumpet))

Thank you for designing one of the most beloved volume management tools on Windows!

---

## 📄 License

EarTrumpet for macOS is licensed under the [MIT License](LICENSE).

#!/bin/bash

# EarTrumpet for Mac Build & Packaging Script

set -e

echo "🎺 Building EarTrumpet for macOS..."

# 1. Build release app binary using Swift Package Manager
swift build -c release

# 2. Compile CoreAudio HAL Plug-In Driver (EarTrumpetDriver)
echo "🎧 Compiling EarTrumpet CoreAudio HAL Driver..."
DRIVER_BUNDLE="build/EarTrumpetDriver.driver"
DRIVER_MACOS="$DRIVER_BUNDLE/Contents/MacOS"

mkdir -p "$DRIVER_MACOS"

clang -bundle -framework CoreAudio -framework CoreFoundation -O3 Driver/EarTrumpetDriver.c -o "$DRIVER_MACOS/EarTrumpetDriver"

cat << 'EOF' > "$DRIVER_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>EarTrumpetDriver</string>
    <key>CFBundleIdentifier</key>
    <string>com.eartrumpet.mac.driver</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>EarTrumpetDriver</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.3.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFPlugInFactories</key>
    <dict>
        <key>EEA5773D-CC43-49F1-8E00-8F96E7D23B17</key>
        <string>EarTrumpetDriverFactory</string>
    </dict>
    <key>CFPlugInTypes</key>
    <dict>
        <key>44343334-3334-3334-3334-333433343334</key>
        <array>
            <string>EEA5773D-CC43-49F1-8E00-8F96E7D23B17</string>
        </array>
    </dict>
</dict>
</plist>
EOF

# 3. Create .app bundle structure
APP_DIR="build/EarTrumpet.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
PLUGINS_DIR="$CONTENTS_DIR/PlugIns"

mkdir -p "$MACOS_DIR"
mkdir -p "$PLUGINS_DIR"

# Copy compiled executable
cp .build/release/EarTrumpet "$MACOS_DIR/EarTrumpet"
cp -R "$DRIVER_BUNDLE" "$PLUGINS_DIR/"

# Create Info.plist with complete macOS privacy & entitlement keys
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>EarTrumpet</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.eartrumpet.mac</string>
    <key>CFBundleName</key>
    <string>EarTrumpet</string>
    <key>CFBundleDisplayName</key>
    <string>EarTrumpet</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.3.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>EarTrumpet requires audio output level measuring to render real-time volume meters.</string>
    <key>NSSystemAudioCaptureUsageDescription</key>
    <string>EarTrumpet requires system audio capture permission to control application volume levels.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>EarTrumpet requires automation permission to control application sound volume.</string>
</dict>
</plist>
EOF

# Code sign ad-hoc deep
codesign --force --deep --sign - "$APP_DIR"

echo "✅ App bundle created and ad-hoc signed at $APP_DIR"
echo "✅ CoreAudio Driver bundle created at $DRIVER_BUNDLE"

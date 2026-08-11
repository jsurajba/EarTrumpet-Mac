#!/bin/bash

# EarTrumpet System-Wide CoreAudio HAL Driver Installer

set -e

echo "=================================================================="
echo "🎺 INSTALLING EARTRUMPET SYSTEM COREAUDIO HAL DRIVER"
echo "=================================================================="

DRIVER_SRC="build/EarTrumpetDriver.driver"
SYS_HAL_DIR="/Library/Audio/Plug-Ins/HAL"
TARGET_DRIVER="$SYS_HAL_DIR/EarTrumpetDriver.driver"

if [ ! -d "$DRIVER_SRC" ]; then
    echo "🔨 Building EarTrumpetDriver..."
    ./scripts/build_app.sh
fi

echo "🔐 Copying driver bundle to $TARGET_DRIVER..."
sudo rm -rf "$TARGET_DRIVER"
sudo cp -R "$DRIVER_SRC" "$SYS_HAL_DIR/"
sudo chown -R root:wheel "$TARGET_DRIVER"
sudo chmod -R 755 "$TARGET_DRIVER"

echo "🔄 Restarting macOS CoreAudio daemon (coreaudiod)..."
sudo launchctl kickstart -k system/com.apple.audio.coreaudiod 2>/dev/null || killall coreaudiod 2>/dev/null || true

echo "=================================================================="
echo "🎉 EARTRUMPET SYSTEM DRIVER INSTALLED AT /Library/Audio/Plug-Ins/HAL/"
echo "=================================================================="

#!/bin/bash

# EarTrumpet CoreAudio Driver Installation Script

set -e

echo "🎧 Installing EarTrumpet CoreAudio HAL Driver..."

HAL_DIR="$HOME/Library/Audio/Plug-Ins/HAL"
mkdir -p "$HAL_DIR"

if [ -d "build/EarTrumpetDriver.driver" ]; then
    cp -R "build/EarTrumpetDriver.driver" "$HAL_DIR/"
    echo "✅ Installed EarTrumpetDriver.driver to $HAL_DIR/EarTrumpetDriver.driver"
else
    echo "❌ Error: build/EarTrumpetDriver.driver not found. Run ./scripts/build_app.sh first."
    exit 1
fi

echo "🔄 Restarting macOS CoreAudio daemon to load new driver..."
killall coreaudiod 2>/dev/null || true

echo "=================================================================="
echo "🎉 EARTRUMPET COREAUDIO HAL DRIVER INSTALLED & ACTIVE!"
echo "=================================================================="

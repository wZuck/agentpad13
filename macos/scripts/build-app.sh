#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/generate-layout.py --check
swift build -c release
bundle="$PWD/dist/AgentPad Studio.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp .build/release/AgentPadStudio "$bundle/Contents/MacOS/AgentPadStudio"
swift scripts/create-icon.swift .build/AgentPad.iconset
iconutil -c icns .build/AgentPad.iconset -o "$bundle/Contents/Resources/AgentPad.icns"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
codesign --force --sign - "$bundle"
printf 'Built: %s\n' "$bundle"

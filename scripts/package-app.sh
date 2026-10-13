#!/bin/sh
# Assembles dist/UltimateMacMonitor.app from the release build and ad-hoc
# signs it for local runs. Distribution signing (Developer ID,
# notarization) is a separate, future step.
set -eu
cd "$(dirname "$0")/.."
APP="dist/UltimateMacMonitor.app"
swift build -c release --product UltimateMacMonitorApp
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/UltimateMacMonitorApp "$APP/Contents/MacOS/UltimateMacMonitor"
cp packaging/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"

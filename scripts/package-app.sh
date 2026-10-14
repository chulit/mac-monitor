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
# Target resources (AppIcon.png/.icns): SwiftPM emits them as
# <package>_<target>.bundle next to the binary; Bundle.module looks the
# bundle up inside Contents/Resources, so copy it whole. CFBundleIconFile
# additionally needs AppIcon.icns directly in Contents/Resources.
mkdir -p "$APP/Contents/Resources"
for b in .build/release/*.bundle; do
  [ -e "$b" ] || continue
  cp -R "$b" "$APP/Contents/Resources/"
  [ -f "$b/AppIcon.icns" ] && cp "$b/AppIcon.icns" "$APP/Contents/Resources/"
done
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"

# Optional relaunch: ./scripts/package-app.sh --relaunch
# NOTE: match MacOS/UltimateMacMonitor, not UltimateMacMonitorApp — the
# binary has no App suffix and a wrong pkill pattern silently relaunches
# the stale build.
if [ "${1:-}" = "--relaunch" ]; then
  pkill -f "MacOS/UltimateMacMonitor" 2>/dev/null || true
  sleep 1
  ditto "$APP" /Applications/UltimateMacMonitor.app
  codesign --verify --deep --strict /Applications/UltimateMacMonitor.app
  open /Applications/UltimateMacMonitor.app
  echo "Reinstalled and relaunched"
fi

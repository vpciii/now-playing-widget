#!/bin/sh
# Build a release copy and install it to /Applications, where it registers
# itself to start at login.
#
# Undo: quit the app (menu bar item, or `pkill -x NowPlaying`), then run
# scripts/uninstall.sh.
set -eu
cd "$(dirname "$0")/.."

DEST="/Applications/NowPlaying.app"

xcodegen generate --quiet
xcodebuild -project NowPlaying.xcodeproj -scheme NowPlaying -configuration Release \
    -derivedDataPath build build -quiet

pkill -x NowPlaying || true
pkill -f 'NowPlayingWidget.appex/Contents/MacOS/NowPlayingWidget' || true
sleep 1

rm -rf "$DEST"
ditto build/Build/Products/Release/NowPlaying.app "$DEST"

# Only one copy of the widget extension should be registered with macOS, so
# remove the build-folder copies now that the installed one exists.
rm -rf build/Build/Products/Debug/NowPlaying.app build/Build/Products/Release/NowPlaying.app

open "$DEST"
echo "Installed and started $DEST"

#!/bin/sh
# Build the app and widget, then run the new build.
#
# macOS keeps the previous widget extension process alive after a rebuild, so
# the desktop keeps showing the old widget code until that process is stopped.
set -eu
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project NowPlaying.xcodeproj -scheme NowPlaying -configuration Debug \
    -derivedDataPath build build -quiet

pkill -x NowPlaying || true
pkill -f 'NowPlayingWidget.appex/Contents/MacOS/NowPlayingWidget' || true
sleep 1
open build/Build/Products/Debug/NowPlaying.app
echo "Now Playing is running from build/Build/Products/Debug/NowPlaying.app"

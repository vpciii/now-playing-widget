#!/bin/sh
# Remove the installed app, its login item and the shared folder.
# The widget disappears from the desktop once the app is gone.
set -eu

DEST="/Applications/NowPlaying.app"

pkill -x NowPlaying || true
pkill -f 'NowPlayingWidget.appex/Contents/MacOS/NowPlayingWidget' || true

# Deleting the app also removes its login item: macOS drops login items
# whose app no longer exists.
rm -rf "$DEST"
rm -rf "$HOME/Library/Application Support/NowPlaying"
echo "Removed $DEST and its data."
echo "To also revoke the Music permission: System Settings > Privacy & Security > Automation."

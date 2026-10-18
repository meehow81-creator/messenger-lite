#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
APP="$ROOT/build/Messenger Lite.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swift "$ROOT/Sources/make-icon.swift" "$ROOT/build/AppIcon.iconset"
/usr/bin/iconutil -c icns "$ROOT/build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
xcrun swiftc -O -default-isolation MainActor -target arm64-apple-macosx14.0 \
    -framework AppKit -framework WebKit \
    "$ROOT/Sources/main.swift" -o "$APP/Contents/MacOS/MessengerLite"
/usr/bin/ditto "$ROOT/Info.plist" "$APP/Contents/Info.plist"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - --options runtime \
    --entitlements "$ROOT/entitlements.plist" "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"

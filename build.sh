#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="build/拾题.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -parse-as-library -O -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macos26.0 Sources/Library.swift Sources/App.swift -o "$APP/Contents/MacOS/QuestionGlass"
cp Info.plist "$APP/Contents/Info.plist"
swift scripts/MakeIcon.swift
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/QuestionGlassIcon.icns"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
echo "已生成：$PWD/$APP"

#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p WowGo.app/Contents/MacOS WowGo.app/Contents/Resources
xcrun swiftc -parse-as-library -O -swift-version 5 Sources/*.swift -o WowGo.app/Contents/MacOS/WowGo
cat > WowGo.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WowGo</string>
<key>CFBundleIdentifier</key><string>com.hwaipy.wowgo.background</string>
<key>CFBundleName</key><string>WowGo</string>
<key>CFBundleDisplayName</key><string>WOW.GO</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>仅捕获魔兽世界窗口，用于预览和浮漂识别。</string>
</dict></plist>
PLIST
cp -R Tests/fixtures WowGo.app/Contents/Resources/
codesign --force --sign - WowGo.app
./WowGo.app/Contents/MacOS/WowGo --self-test

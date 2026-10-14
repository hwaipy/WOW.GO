#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p FishGo.app/Contents/MacOS FishGo.app/Contents/Resources
xcrun swiftc -parse-as-library -O -swift-version 5 Sources/*.swift -o FishGo.app/Contents/MacOS/FishGo
cat > FishGo.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FishGo</string>
<key>CFBundleIdentifier</key><string>com.hwaipy.wowgo.background</string>
<key>CFBundleName</key><string>FishGo</string>
<key>CFBundleDisplayName</key><string>FishGo</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>仅捕获魔兽世界窗口，用于预览和浮漂识别。</string>
</dict></plist>
PLIST
cp -R Tests/fixtures FishGo.app/Contents/Resources/
codesign --force --sign - FishGo.app
./FishGo.app/Contents/MacOS/FishGo --self-test

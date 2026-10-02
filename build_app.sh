#!/bin/bash
# 编译并打包成 build/打字小能手.app
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="打字小能手"
EXEC_NAME="TypingKids"
BUNDLE="build/${APP_NAME}.app"

echo "▶ 编译 (release)…"
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)

echo "▶ 生成图标…"
mkdir -p build
if [ ! -f build/AppIcon.icns ]; then
    rm -rf build/AppIcon.iconset
    swift Scripts/make_icon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi

echo "▶ 检查语音录音（只补录缺少的）…"
# 第三方 App 不能直接调用 Siri 自然语音，所以用 swift 解释器预先录好，录音提交在 Resources/Voices
cat Sources/TypingKids/Support/VoiceLines.swift Scripts/make_voices.swift > build/_make_voices.swift
swift build/_make_voices.swift Resources/Voices

echo "▶ 打包 ${BUNDLE}…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/$EXEC_NAME" "$BUNDLE/Contents/MacOS/$EXEC_NAME"
cp build/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
if ls Resources/Voices/*.m4a >/dev/null 2>&1; then
    mkdir -p "$BUNDLE/Contents/Resources/Voices"
    cp Resources/Voices/*.m4a "$BUNDLE/Contents/Resources/Voices/"
fi

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>${EXEC_NAME}</string>
    <key>CFBundleIdentifier</key><string>com.fengyiyi.typingkids</string>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$BUNDLE" >/dev/null
echo "✅ 完成：$BUNDLE"
echo "   运行：open \"$BUNDLE\"   或拖到「应用程序」文件夹"

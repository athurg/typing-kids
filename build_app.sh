#!/bin/bash
# 编译并打包成 build/dzxns.app（访达、启动台里显示为「打字小能手」）
#
# 可选环境变量：
#   VERSION=1.2.0     版本号（默认取最近的 git 标签，如 v1.0.0 → 1.0.0）
#   BUILD_NUMBER=42   构建号（默认是提交次数）
#   UNIVERSAL=1       同时编译 Apple 芯片和 Intel 版本
#   ZIP=1             额外打一个 build/TypingKids-<版本>.zip，方便分发
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="打字小能手"
EXEC_NAME="TypingKids"
# 包的文件名用拼音首字母，Spotlight / 启动台搜 dzxns 就能找到；
# Info.plist 里的名字必须和文件名一致，系统才会改用 InfoPlist.strings 里的中文名显示
BUNDLE_NAME="dzxns"
BUNDLE="build/${BUNDLE_NAME}.app"

VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

ARCH_FLAGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "▶ 编译 (release, 版本 ${VERSION} (${BUILD_NUMBER})${UNIVERSAL:+, 通用二进制})…"
# bash 3.2 下空数组配合 set -u 会报错，所以用 ${arr[@]+...} 的写法
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR=$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)

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
rm -rf "$BUNDLE" "build/${APP_NAME}.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/$EXEC_NAME" "$BUNDLE/Contents/MacOS/$EXEC_NAME"
cp build/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
if ls Resources/Voices/*.m4a >/dev/null 2>&1; then
    mkdir -p "$BUNDLE/Contents/Resources/Voices"
    cp Resources/Voices/*.m4a "$BUNDLE/Contents/Resources/Voices/"
fi
for LPROJ in zh-Hans en; do
    mkdir -p "$BUNDLE/Contents/Resources/${LPROJ}.lproj"
    printf 'CFBundleName = "%s";\nCFBundleDisplayName = "%s";\n' "$APP_NAME" "$APP_NAME" \
        > "$BUNDLE/Contents/Resources/${LPROJ}.lproj/InfoPlist.strings"
done

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>${EXEC_NAME}</string>
    <key>CFBundleIdentifier</key><string>com.fengyiyi.typingkids</string>
    <key>CFBundleName</key><string>${BUNDLE_NAME}</string>
    <key>CFBundleDisplayName</key><string>${BUNDLE_NAME}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>LSHasLocalizedDisplayName</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$BUNDLE" >/dev/null
echo "✅ 完成：${BUNDLE}（版本 ${VERSION}，构建 ${BUILD_NUMBER}）"

if [ "${ZIP:-0}" = "1" ]; then
    ZIP_PATH="build/TypingKids-${VERSION}.zip"
    rm -f "$ZIP_PATH"
    # ditto 打包能保留 App 包的权限和签名
    ditto -c -k --keepParent "$BUNDLE" "$ZIP_PATH"
    echo "📦 压缩包：${ZIP_PATH}"
    # 给 CI 用：把压缩包路径写到 GitHub Actions 的输出里
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "zip=$ZIP_PATH" >> "$GITHUB_OUTPUT"
        echo "version=$VERSION" >> "$GITHUB_OUTPUT"
    fi
else
    echo "   运行：open \"$BUNDLE\"   或拖到「应用程序」文件夹"
fi

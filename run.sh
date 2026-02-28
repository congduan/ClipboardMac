#!/bin/bash

set -e

echo "开始编译 ClipboardMac 项目..."

# 清理之前的构建
echo "清理之前的构建..."
xcodebuild clean -project ClipboardMac.xcodeproj -scheme ClipboardMac -configuration Debug 2>/dev/null || true

# 生成 Xcode 项目
echo "生成 Xcode 项目..."
xcodegen generate

# 编译项目
echo "编译项目..."
xcodebuild -project ClipboardMac.xcodeproj -scheme ClipboardMac -configuration Debug build

# 查找应用程序
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ClipboardMac-*/Build/Products/Debug/ClipboardMac.app -maxdepth 0 -type d 2>/dev/null | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "错误：找不到编译后的应用程序"
    exit 1
fi

echo "找到应用程序: $APP_PATH"
echo "运行应用程序..."
open "$APP_PATH"

echo "=== 操作完成 ==="

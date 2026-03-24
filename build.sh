#!/bin/bash
# SIKMUBYNCH 빌드 스크립트
# 사용법: bash build.sh

GODOT="/d/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe"
PROJECT="D:/reference2/sikmubynch/project"
BUILD_DIR="D:/reference2/sikmubynch/build"

mkdir -p "$BUILD_DIR"

echo "=== SIKMUBYNCH 빌드 시작 ==="
echo ""

# Export
"$GODOT" --headless --path "$PROJECT" --export-release "Windows" "$BUILD_DIR/SIKMUBYNCH.exe" 2>&1

if [ $? -eq 0 ] && [ -f "$BUILD_DIR/SIKMUBYNCH.exe" ]; then
    SIZE=$(du -h "$BUILD_DIR/SIKMUBYNCH.exe" | cut -f1)
    echo ""
    echo "=== 빌드 성공! ==="
    echo "파일: $BUILD_DIR/SIKMUBYNCH.exe ($SIZE)"
    echo ""
    echo "실행하려면:"
    echo "  $BUILD_DIR/SIKMUBYNCH.exe"
    echo ""
    # 자동 실행
    read -p "바로 실행할까요? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$BUILD_DIR/SIKMUBYNCH.exe" &
    fi
else
    echo ""
    echo "=== 빌드 실패 ==="
fi

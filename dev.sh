#!/bin/bash
# dev.sh - 검증 → 빌드 → 실행 한 번에
GODOT="/d/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe"
PROJECT="D:/reference2/sikmubynch/project"
BUILD_DIR="D:/reference2/sikmubynch/build"

echo "=== [1/3] GDScript 검증 ==="
ERRORS=$("$GODOT" --headless --path "$PROJECT" --quit 2>&1)
if echo "$ERRORS" | grep -qi "SCRIPT ERROR\|Parse Error"; then
    echo "FAILED:"
    echo "$ERRORS" | grep -i "SCRIPT ERROR\|Parse Error"
    exit 1
fi
echo "OK"

echo "=== [2/3] Windows 빌드 ==="
mkdir -p "$BUILD_DIR"
"$GODOT" --headless --path "$PROJECT" --export-release "Windows" "$BUILD_DIR/SIKMUBYNCH.exe" 2>&1 | tail -1
if [ ! -f "$BUILD_DIR/SIKMUBYNCH.exe" ]; then
    echo "BUILD FAILED"
    exit 2
fi
echo "OK ($(du -h "$BUILD_DIR/SIKMUBYNCH.exe" | cut -f1))"

echo "=== [3/3] 실행 ==="
"$BUILD_DIR/SIKMUBYNCH.exe" &
echo "SIKMUBYNCH.exe launched"

#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export MACOSX_DEPLOYMENT_TARGET=11.0

NO_LAUNCH=false
for arg in "$@"; do
    [[ "$arg" == "--no-launch" ]] && NO_LAUNCH=true
done

echo "Generating AppIcon.icns..."
swift make_icon.swift

echo "Building SwitchBack (universal)..."
swift build -c release --arch arm64
swift build -c release --arch x86_64

echo "Lipoing universal binary..."
mkdir -p .build/release
lipo -create \
    .build/arm64-apple-macosx/release/SwitchBack \
    .build/x86_64-apple-macosx/release/SwitchBack \
    -output .build/release/SwitchBack

BINARY=".build/release/SwitchBack"
APP_DIR="SwitchBack.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Assembling .app bundle..."
rm -rf "$APP_DIR" 2>/dev/null || sudo rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BINARY"      "$MACOS/SwitchBack"
cp "Info.plist"   "$CONTENTS/Info.plist"
cp "AppIcon.icns" "$RESOURCES/AppIcon.icns"

CERT_NAME="SwitchBack Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$CERT_NAME\""; then
    echo "Code signing (self-signed: $CERT_NAME)..."
    codesign --force --deep \
        --entitlements "$SCRIPT_DIR/entitlements.plist" \
        --sign "$CERT_NAME" "$APP_DIR"
else
    echo "Code signing (ad-hoc — run setup-cert.sh for persistent TCC)..."
    codesign --force --deep \
        --entitlements "$SCRIPT_DIR/entitlements.plist" \
        --sign - "$APP_DIR"
fi

if [[ "$NO_LAUNCH" == false ]]; then
    echo "Done. Launching SwitchBack.app..."
    pkill -x SwitchBack 2>/dev/null || true
    sleep 0.5
    open "$APP_DIR"
else
    echo "Done: $APP_DIR"
fi

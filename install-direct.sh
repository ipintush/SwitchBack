#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DEST="/Applications/SwitchBack.app"

echo "=== Building SwitchBack ==="
bash "$SCRIPT_DIR/build.sh" --no-launch

echo ""
echo "=== Installing to /Applications ==="
# sudo only to remove existing root-owned app; copy WITHOUT sudo so files are user-owned
# (mdworker/Spotlight cannot index root-owned files)
sudo rm -rf "$DEST"
cp -r "$SCRIPT_DIR/SwitchBack.app" "$DEST"
xattr -cr "$DEST"

echo ""
echo "=== Registering with Spotlight ==="
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
mdimport "$DEST"

echo ""
echo "Done! Launching SwitchBack..."
# Reset TCC only if the previous binary was ad-hoc signed (not self-signed)
AUTHORITY=$(codesign -dv "$DEST" 2>&1 | grep "Authority=" | head -1 || true)
if [[ "$AUTHORITY" != *"SwitchBack"* ]]; then
    tccutil reset Accessibility com.switchback.app 2>/dev/null || true
fi
open "$DEST"

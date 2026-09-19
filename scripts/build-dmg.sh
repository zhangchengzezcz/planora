#!/bin/bash
set -euo pipefail

if [[ $# != 3 ]]; then
    echo 'Usage: build-dmg.sh app-path output.dmg dmg-tools-venv' >&2
    exit 2
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$1"
output="$2"
tools="$3"

[[ -d "$app" ]] || {
    echo "ERROR: App does not exist: $app" >&2
    exit 1
}

[[ ! -e "$output" ]] || {
    echo "ERROR: Output already exists: $output" >&2
    exit 1
}

version=$(
    /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleShortVersionString' \
        "$app/Contents/Info.plist"
)

volume_name="Planora $version"
work="$(mktemp -d /tmp/planora-dmg.XXXXXX)"
mount_point="$work/mount"
verify_point="$work/verify"

detach_point() {
    local point="$1"

    [[ -d "$point" ]] || return 0

    local device
    device="$(df "$point" 2>/dev/null | tail -1 | awk '{print $1}' || true)"

    if [[ "$device" == /dev/* ]]; then
        hdiutil detach "$device" >/dev/null 2>&1 || \
        hdiutil detach -force "$device" >/dev/null 2>&1 || true
    fi
}

cleanup() {
    set +e
    detach_point "$verify_point"
    detach_point "$mount_point"
    rm -rf "$work"
}

trap cleanup EXIT INT TERM

echo
echo "===== CREATE EDITABLE DMG ====="

"$tools/bin/dmgbuild" \
    -s "$root/scripts/dmg-settings.py" \
    -D app="$app" \
    -D guide="$root/updates/INSTALLATION.txt" \
    -D background="$root/updates/assets/dmg-background.png" \
    -D format=UDRW \
    "$volume_name" \
    "$work/editable.dmg"

mkdir "$mount_point"

echo
echo "===== MOUNT EDITABLE DMG ====="

hdiutil attach \
    -readwrite \
    -noverify \
    -noautoopen \
    -mountpoint "$mount_point" \
    "$work/editable.dmg" \
    >/dev/null

echo
echo "===== MOVE BACKGROUND INSIDE DMG ====="

"$tools/bin/python" \
    "$root/scripts/finalize-dmg-background.py" \
    "$mount_point"

background_path="$mount_point/.background/installation.png"

[[ -f "$background_path" ]] || {
    echo "ERROR: Embedded background missing."
    exit 1
}

cmp \
    "$root/updates/assets/dmg-background.png" \
    "$background_path"

app_name="$(basename "$app")"

echo
echo "===== LET FINDER WRITE NATIVE METADATA ====="
echo "Finder may briefly open the DMG window."

rm -f "$mount_point/.DS_Store"

open "$mount_point"

sleep 2

/usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
    activate

    set dmgFolder to POSIX file "$mount_point" as alias
    set bgFile to POSIX file "$background_path" as alias

    set dmgWindow to container window of folder dmgFolder

    set current view of dmgWindow to icon view
    set toolbar visible of dmgWindow to false
    set statusbar visible of dmgWindow to false
    set pathbar visible of dmgWindow to false

    set bounds of dmgWindow to {120, 120, 840, 580}

    set viewOptions to icon view options of dmgWindow

    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set text size of viewOptions to 14
    set background picture of viewOptions to bgFile

    set position of item "$app_name" of folder dmgFolder to {190, 210}
    set position of item "Applications" of folder dmgFolder to {530, 210}
    set position of item "INSTALLATION.txt" of folder dmgFolder to {620, 350}

    update folder dmgFolder without registering applications

    delay 2

    close dmgWindow
end tell
APPLESCRIPT

sleep 2

echo
echo "===== FORCE FINDER METADATA FLUSH ====="

sync
sleep 2

[[ -f "$mount_point/.DS_Store" ]] || {
    echo "ERROR: Finder did not create .DS_Store."
    exit 1
}

[[ -f "$mount_point/.background/installation.png" ]] || {
    echo "ERROR: Background disappeared."
    exit 1
}

[[ ! -e "$mount_point/.background.png" ]] || {
    echo "ERROR: Old root background still exists."
    exit 1
}

[[ -L "$mount_point/Applications" ]] || {
    echo "ERROR: Applications symlink missing."
    exit 1
}

[[ -f "$mount_point/INSTALLATION.txt" ]] || {
    echo "ERROR: INSTALLATION.txt missing."
    exit 1
}

codesign \
    --verify \
    --deep \
    --strict \
    "$mount_point/$app_name"

echo
echo "Finder metadata created successfully."

detach_point "$mount_point"

echo
echo "===== CONVERT FINAL DMG ====="

hdiutil convert \
    "$work/editable.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$output" \
    >/dev/null

echo
echo "===== VERIFY IMAGE CHECKSUM ====="

hdiutil verify "$output"

echo
echo "===== REMOUNT FINAL IMAGE ====="

mkdir "$verify_point"

hdiutil attach \
    -readonly \
    -nobrowse \
    -noautoopen \
    -mountpoint "$verify_point" \
    "$output" \
    >/dev/null

echo
echo "===== FINAL CONTENT ====="

ls -la "$verify_point"

echo
echo "===== BACKGROUND ====="

ls -la "$verify_point/.background"

[[ -f "$verify_point/.background/installation.png" ]] || {
    echo "ERROR: Final background missing."
    exit 1
}

[[ -f "$verify_point/.DS_Store" ]] || {
    echo "ERROR: Final .DS_Store missing."
    exit 1
}

[[ -L "$verify_point/Applications" ]] || {
    echo "ERROR: Final Applications symlink missing."
    exit 1
}

[[ -f "$verify_point/INSTALLATION.txt" ]] || {
    echo "ERROR: Final INSTALLATION.txt missing."
    exit 1
}

cmp \
    "$root/updates/assets/dmg-background.png" \
    "$verify_point/.background/installation.png"

codesign \
    --verify \
    --deep \
    --strict \
    "$verify_point/$app_name"

echo
echo "Final structural verification: OK"

detach_point "$verify_point"

echo
echo "========================================"
echo " FINDER-NATIVE TEST DMG PASSED"
echo "========================================"
echo "$output"

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
[[ ! -e "$output" ]] || { echo 'Output already exists.' >&2; exit 1; }
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
work=$(mktemp -d /tmp/planora-dmg.XXXXXX)
cleanup() {
    if mount | grep -Fq "on $work/mount "; then
        hdiutil detach "$work/mount" >/dev/null || return
    fi
    rm -rf "$work"
}
trap cleanup EXIT
"$tools/bin/dmgbuild" -s "$root/scripts/dmg-settings.py" \
    -D app="$app" -D guide="$root/updates/INSTALLATION.txt" \
    -D background="$root/updates/assets/dmg-background.png" -D format=UDRW \
    "Planora $version" "$work/editable.dmg"
mkdir "$work/mount"
hdiutil attach -nobrowse -mountpoint "$work/mount" "$work/editable.dmg" >/dev/null
"$tools/bin/python" "$root/scripts/finalize-dmg-background.py" "$work/mount"
cmp "$root/updates/assets/dmg-background.png" "$work/mount/.background/installation.png"
codesign --verify --deep --strict "$work/mount/$(basename "$app")"
hdiutil detach "$work/mount" >/dev/null
hdiutil convert "$work/editable.dmg" -format UDZO -o "$output" >/dev/null
hdiutil verify "$output"

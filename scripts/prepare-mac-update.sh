#!/bin/bash
set -euo pipefail

# Prepare a signed release in a separate directory. This script never uploads.
if [[ $# -ne 3 ]]; then
    printf 'Usage: bash scripts/prepare-mac-update.sh /path/planora.app /path/notes.md /path/output\n' >&2
    exit 2
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$1"
notes="$2"
output="$3"
plist="$app/Contents/Info.plist"
account="com.zhangchengze.planora.mac"
cache="${HOME}/Library/Caches/PlanoraReleaseTools/Sparkle-2.9.6"
expected="8d5fb41d960b43f4a68aa14126bf62b098544ec8d191cdcc73eb14e63a8e7606"

[[ -f "$plist" && -f "$notes" ]] || { printf 'App or release notes are missing.\n' >&2; exit 1; }
[[ ! -e "$output" ]] || { printf 'Output must be a new directory.\n' >&2; exit 1; }
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")
[[ "$identifier" == "$account" ]] || { printf 'Not a Planora Mac app.\n' >&2; exit 1; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$build" =~ ^[0-9]+$ ]] || exit 1
key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$plist")
expected_key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$root/planora/Mac/Info.plist")
[[ "$key" == "$expected_key" ]] || { printf 'Signing public key does not match.\n' >&2; exit 1; }
[[ -d "$app/Contents/Frameworks/Sparkle.framework" ]] || exit 1
/usr/bin/codesign --verify --deep --strict "$app"

if [[ ! -x "$cache/bin/generate_appcast" ]]; then
    mkdir -p "$cache"
    /usr/bin/curl -fL --connect-timeout 15 --max-time 180 --retry 2 \
        'https://github.com/sparkle-project/Sparkle/releases/download/2.9.6/Sparkle-for-Swift-Package-Manager.zip' \
        -o "$cache/distribution.zip"
    actual=$(/usr/bin/shasum -a 256 "$cache/distribution.zip")
    [[ "${actual%% *}" == "$expected" ]] || { printf 'Sparkle checksum mismatch.\n' >&2; exit 1; }
    /usr/bin/ditto -x -k "$cache/distribution.zip" "$cache"
fi
public_key=$("$cache/bin/generate_keys" --account "$account" -p)
[[ "$public_key" == "$key" ]] || { printf 'Matching signing key is unavailable in Keychain.\n' >&2; exit 1; }

mkdir -p "$output"
archive="Planora-${version}-macOS.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$output/$archive"
cp "$notes" "$output/Planora-${version}-macOS.md"
cp "$root/updates/appcast.xml" "$output/appcast.xml"
"$cache/bin/generate_appcast" --account "$account" --maximum-deltas 0 \
    --versions "$build" --embed-release-notes \
    --download-url-prefix "https://github.com/zhangchengzezcz/planora/releases/download/${version}/" \
    "$output"
"$cache/bin/sign_update" --account "$account" --verify "$output/appcast.xml"
printf 'Prepared %s and signed appcast.xml. Upload the archive before publishing the feed.\n' "$archive"

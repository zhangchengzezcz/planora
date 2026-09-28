#!/bin/bash
set -euo pipefail
app="${1:?App path required}"
/usr/bin/codesign --verify --deep --strict "$app"
signature=$(/usr/bin/codesign -dv --verbose=4 "$app" 2>&1)
if [[ "$signature" == *"Signature=adhoc"* && "$signature" == *"runtime)"* ]]; then
    entitlements=$(/usr/bin/codesign -d --entitlements :- "$app" 2>/dev/null)
    exception=$(printf '%s' "$entitlements" | /usr/bin/plutil -extract 'com\.apple\.security\.cs\.disable-library-validation' raw -o - - 2>/dev/null || true)
    [[ "$exception" == "true" ]] || {
        echo "ERROR: Ad-hoc Hardened Runtime cannot load Sparkle without a library-validation exception." >&2
        exit 1
    }
fi

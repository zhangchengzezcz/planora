#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
derived="${1:?Provide a dedicated derived-data directory}"
cd "$root"
xcodebuild -project planora.xcodeproj -scheme planora -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$derived" \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    CODE_SIGN_ENTITLEMENTS=scripts/adhoc-release.entitlements build
bash scripts/verify-mac-signing.sh "$derived/Build/Products/Release/planora.app"

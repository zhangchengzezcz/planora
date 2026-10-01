#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
developer="${DEVELOPER_DIR:-$(xcode-select -p)}"
exporter="$developer/../Applications/Icon Composer.app/Contents/Executables/ictool"
[[ -x "$exporter" ]] || { printf 'Icon Composer exporter is unavailable.\n' >&2; exit 1; }
mkdir -p "$root/planora/Brand"
for appearance in Light Dark; do
    rendition=Default
    [[ "$appearance" != Dark ]] || rendition=Dark
    "$exporter" "$root/Planora Full.icon" --export-image \
        --output-file "$root/planora/Brand/PlanoraBrand${appearance}.png" \
        --platform iOS --rendition "$rendition" --width 384 --height 384 --scale 1 --design-generation 27
done
cp "$root/planora/Brand/PlanoraBrandLight.png" "$root/web-demo/public/brand-light.png"
cp "$root/planora/Brand/PlanoraBrandDark.png" "$root/web-demo/public/brand-dark.png"
"$exporter" "$root/Planora Full.icon" --export-image \
    --output-file "$root/web-demo/public/icon.png" \
    --platform iOS --rendition Default --width 64 --height 64 --scale 1 --design-generation 27

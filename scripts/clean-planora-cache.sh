#!/bin/bash
set -euo pipefail
# Only the app-owned cache directory is disposable. Never traverse Library.
cache="$HOME/Library/Caches/com.zhangchengze.planora.mac"
case "${1:---dry-run}" in
    --dry-run) printf 'Disposable cache only / 仅可清理缓存: %s\n' "$cache" ;;
    --execute)
        if pgrep -x planora >/dev/null; then
            echo "Quit Planora before clearing caches / 请先退出 Planora" >&2
            exit 1
        fi
        [[ ! -L "$cache" ]] || { echo "Refusing symbolic-link cache path" >&2; exit 1; }
        rm -rf -- "$cache"
        ;;
    *) echo "Usage: bash scripts/clean-planora-cache.sh [--dry-run|--execute]" >&2; exit 2 ;;
esac

import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("Usage: finalize-dmg-background.py MOUNT_POINT")

volume = Path(sys.argv[1]).resolve()

source = volume / ".background.png"
folder = volume / ".background"
destination = folder / "installation.png"

if not source.is_file():
    raise SystemExit(
        f"ERROR: dmgbuild background source missing: {source}"
    )

folder.mkdir(exist_ok=True)

if destination.exists():
    destination.unlink()

source.rename(destination)

if not destination.is_file():
    raise SystemExit(
        "ERROR: Could not move background into .background"
    )

print(destination)

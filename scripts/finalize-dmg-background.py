"""Embed Finder's background inside the mounted image, independent of build paths."""
import sys
from pathlib import Path

from ds_store import DSStore
from mac_alias import Alias, Bookmark

volume = Path(sys.argv[1]).resolve()
source = volume / ".background.png"
folder = volume / ".background"
folder.mkdir(exist_ok=True)
destination = folder / "installation.png"
source.rename(destination)
with DSStore.open(str(volume / ".DS_Store"), "r+") as store:
    settings = store["."]["icvp"]
    settings["backgroundType"] = 2
    settings["backgroundImageAlias"] = Alias.for_file(str(destination)).to_bytes()
    store["."]["icvp"] = settings
    store["."]["pBBk"] = Bookmark.for_file(str(destination))
    store["."]["icvl"] = ("type", b"icnv")

import os

format = defines.get("format", "UDZO")
filesystem = "HFS+"
files = [defines["app"], (defines["guide"], "INSTALLATION.txt")]
symlinks = {"Applications": "/Applications"}
background = defines["background"]
window_rect = ((120, 120), (720, 460))
default_view = "icon-view"
show_toolbar = False
show_status_bar = False
show_sidebar = False
show_pathbar = False
include_icon_view_settings = True
icon_size = 96
text_size = 14
icon_locations = {os.path.basename(defines["app"]): (190, 210), "Applications": (530, 210), "INSTALLATION.txt": (650, 402)}

# Extra: pane, a Wayland display server written from scratch
# https://github.com/irawoodring/desktop_environment
# Package: pane-175bd91e3171.tar.gz
# Optional: GUI=yes
#
# Draws straight to the screen through DRM/KMS (/dev/dri/card0), reads the
# keyboard and mouse from /dev/input, and runs unmodified Wayland apps. Its look
# is a CSS file. Try it from a text console under `./laker run --gui`:
#
#   pane -s pane-demo         # Ctrl+Alt+Backspace quits
#
# Without libcss and FreeType (not in LFS), pane uses its built-in CSS engine
# and the console fonts from kbd. The theme it ships is /usr/share/pane/theme.css;
# copy it to ~/.config/pane/theme.css to change it.

make CC=gcc PREFIX=/usr

make CC=gcc PREFIX=/usr install

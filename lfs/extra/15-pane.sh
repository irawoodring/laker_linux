# Extra: pane, a Wayland display server written from scratch
# https://github.com/irawoodring/desktop_environment
# Package: pane-0c5a834b7eb8.tar.gz
# Optional: GUI=yes
#
# Draws straight to the screen through DRM/KMS (/dev/dri/card0), reads the
# keyboard and mouse from /dev/input, and runs unmodified Wayland apps. Its look
# is a CSS file. Try it from a text console under `./laker run --gui`:
#
#   pane -s pane-demo         # Ctrl+Alt+Backspace quits
#
# Super+Enter (or Ctrl+Alt+T) opens foot, built in the step before.
#
# This step comes last so pane finds FreeType and the DejaVu fonts and draws
# its titles and menus with them. libcss isn't here, so it uses its built-in CSS
# engine. The theme it ships is /usr/share/pane/theme.css; copy it to
# ~/.config/pane/theme.css to change it.

make CC=gcc PREFIX=/usr

make CC=gcc PREFIX=/usr install

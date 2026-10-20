# Extra: foot-1.27.0 (not in BLFS)
# https://codeberg.org/dnkl/foot
# Package: foot-1.27.0.tar.gz
# Optional: GUI=yes
#
# A fast, lightweight Wayland terminal. Under pane, Super+Enter or Ctrl+Alt+T
# opens one. Its settings go in ~/.config/foot/foot.ini.
# LakerLinux: no documentation (needs scdoc), no grapheme clustering (needs
# utf8proc), no tests, and no utmp logging (needs libutempter). Its terminfo
# entry is compiled with ncurses' tic, from LFS.

mkdir build &&
cd    build &&

meson setup ..                          \
      --prefix=/usr                     \
      --buildtype=release               \
      -D docs=disabled                  \
      -D grapheme-clustering=disabled   \
      -D tests=false                    \
      -D utmp-backend=none &&
ninja

ninja install

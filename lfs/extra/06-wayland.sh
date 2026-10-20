# Extra: Wayland-1.24.0 (from BLFS 12.4)
# https://www.linuxfromscratch.org/blfs/view/12.4/general/wayland.html
# Package: wayland-1.24.0.tar.xz
# Optional: GUI=yes
#
# libwayland: the library Wayland apps (foot, below) use to talk to a display
# server such as pane, and wayland-scanner, which turns protocol XML files
# into C code.
# LakerLinux: BLFS requires libxml2, which wayland-scanner only uses to check
# protocol files against their DTD; LFS doesn't have it, so that check is off
# (-D dtd_validation=false). The test suite isn't built.

mkdir build &&
cd    build &&

meson setup ..                  \
      --prefix=/usr             \
      --buildtype=release       \
      -D documentation=false    \
      -D dtd_validation=false   \
      -D tests=false &&
ninja

ninja install

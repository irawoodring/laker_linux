# Extra: libxkbcommon-1.11.0 (from BLFS 12.4)
# https://www.linuxfromscratch.org/blfs/view/12.4/general/libxkbcommon.html
# Package: libxkbcommon-1.11.0.tar.gz
#
# Turns key codes from the kernel into characters, using a layout from
# xkeyboard-config. Every Wayland display server and app uses it.
# LakerLinux: the parts that need packages LFS doesn't have are switched off:
# X11 support (libxcb), the Wayland tools (Wayland), and libxkbregistry (libxml2).

mkdir build &&
cd    build &&

meson setup ..                     \
      --prefix=/usr                \
      --buildtype=release          \
      -D enable-docs=false         \
      -D enable-x11=false          \
      -D enable-wayland=false      \
      -D enable-xkbregistry=false &&
ninja

ninja install

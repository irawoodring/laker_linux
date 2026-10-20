# Extra: Wayland-Protocols-1.45 (from BLFS 12.4)
# https://www.linuxfromscratch.org/blfs/view/12.4/general/wayland-protocols.html
# Package: wayland-protocols-1.45.tar.xz
# Optional: GUI=yes
#
# The XML descriptions of Wayland's extension protocols (windows, decorations,
# clipboard, ...), which apps compile in with wayland-scanner.
# LakerLinux: the test suite isn't built.

mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release -D tests=false .. &&
ninja

ninja install

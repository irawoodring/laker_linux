# Extra: tllist-1.1.0 (not in BLFS)
# https://codeberg.org/dnkl/tllist
# Package: tllist-1.1.0.tar.gz
# Optional: GUI=yes
#
# A typed linked list for C, as a single header file. fcft and foot use it.

mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release .. &&
ninja

ninja install

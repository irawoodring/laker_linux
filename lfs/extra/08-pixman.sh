# Extra: Pixman-0.46.4 (from BLFS 12.4)
# https://www.linuxfromscratch.org/blfs/view/12.4/general/pixman.html
# Package: pixman-0.46.4.tar.gz
# Optional: GUI=yes
#
# Fast pixel operations (filling, compositing, scaling), which foot draws with.

mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release .. &&
ninja

ninja install

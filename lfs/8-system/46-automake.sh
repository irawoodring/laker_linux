# LFS 12.4, 8.47. Automake-1.18.1
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/automake.html
# Package: automake-1.18.1.tar.xz

./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1

make

# LakerLinux: test suite left out (see README.md).

make install

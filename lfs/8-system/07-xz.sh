# LFS 12.4, 8.8. Xz-5.8.1
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/xz.html
# Package: xz-5.8.1.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.8.1

make

make install

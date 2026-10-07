# LFS 12.4, 8.50. Libffi-3.5.2
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/libffi.html
# Package: libffi-3.5.2.tar.gz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr    \
            --disable-static \
            --with-gcc-arch=native

make

make install

# LFS 12.4, 8.38. GDBM-1.26
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/gdbm.html
# Package: gdbm-1.26.tar.gz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat

make

make install

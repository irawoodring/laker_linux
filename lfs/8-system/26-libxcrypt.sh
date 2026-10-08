# LFS 12.4, 8.27. Libxcrypt-4.4.38
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/libxcrypt.html
# Package: libxcrypt-4.4.38.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no     \
            --disable-static             \
            --disable-failure-tokens

make

make install

make distclean
./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=glibc  \
            --disable-static             \
            --disable-failure-tokens
make
cp -av --remove-destination .libs/libcrypt.so.1* /usr/lib

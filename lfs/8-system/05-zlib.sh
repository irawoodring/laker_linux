# LFS 12.4, 8.6. Zlib-1.3.1
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/zlib.html
# Package: zlib-1.3.1.tar.gz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr

make

make install

rm -fv /usr/lib/libz.a

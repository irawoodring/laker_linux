# LFS 12.4, 8.37. Libtool-2.5.4
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/libtool.html
# Package: libtool-2.5.4.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr

make

make install

rm -fv /usr/lib/libltdl.a

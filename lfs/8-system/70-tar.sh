# LFS 12.4, 8.71. Tar-1.35
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/tar.html
# Package: tar-1.35.tar.xz
# (1 test-suite command block(s) from the book left out.)

FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr

make

make install
make -C doc install-html docdir=/usr/share/doc/tar-1.35

# LFS 12.4, 8.25. Acl-2.3.2
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/acl.html
# Package: acl-2.3.2.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.3.2

make

make install

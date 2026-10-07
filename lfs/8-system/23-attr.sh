# LFS 12.4, 8.24. Attr-2.5.2
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/attr.html
# Package: attr-2.5.2.tar.gz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.5.2

make

make install

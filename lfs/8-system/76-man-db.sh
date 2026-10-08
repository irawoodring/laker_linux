# LFS 12.4, 8.77. Man-DB-2.13.1
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/man-db.html
# Package: man-db-2.13.1.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr                         \
            --docdir=/usr/share/doc/man-db-2.13.1 \
            --sysconfdir=/etc                     \
            --disable-setuid                      \
            --enable-cache-owner=bin              \
            --with-browser=/usr/bin/lynx          \
            --with-vgrind=/usr/bin/vgrind         \
            --with-grap=/usr/bin/grap             \
            --with-systemdtmpfilesdir=            \
            --with-systemdsystemunitdir=

make

make install

# LFS 12.4, 8.33. Gettext-0.26
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/gettext.html
# Package: gettext-0.26.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.26

make

make install
chmod -v 0755 /usr/lib/preloadable_libintl.so

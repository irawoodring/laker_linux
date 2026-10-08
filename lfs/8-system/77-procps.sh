# LFS 12.4, 8.78. Procps-ng-4.0.5
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/procps.html
# Package: procps-ng-4.0.5.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr                           \
            --docdir=/usr/share/doc/procps-ng-4.0.5 \
            --disable-static                        \
            --disable-kill                          \
            --enable-watch8bit

make

make install

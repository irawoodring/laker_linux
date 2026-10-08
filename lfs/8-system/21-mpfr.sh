# LFS 12.4, 8.22. MPFR-4.2.2
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/mpfr.html
# Package: mpfr-4.2.2.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.2

make
make html

make install
make install-html

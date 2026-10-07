# LFS 12.4, 8.21. GMP-6.3.0
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/gmp.html
# Package: gmp-6.3.0.tar.xz
# (1 test-suite command block(s) from the book left out.)

ABI=32 ./configure ...

sed -i '/long long t1;/,+1s/()/(...)/' configure

./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0

make
make html

# LakerLinux: the book counts the test suite's passes here; tests are skipped.

make install
make install-html

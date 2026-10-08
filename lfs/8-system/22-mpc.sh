# LFS 12.4, 8.23. MPC-1.3.1
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/mpc.html
# Package: mpc-1.3.1.tar.gz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.3.1

make
make html

make install
make install-html

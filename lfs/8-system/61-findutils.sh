# LFS 12.4, 8.62. Findutils-4.10.0
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/findutils.html
# Package: findutils-4.10.0.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr --localstatedir=/var/lib/locate

make

make install

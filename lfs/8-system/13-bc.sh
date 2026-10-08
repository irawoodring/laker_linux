# LFS 12.4, 8.14. Bc-7.0.3
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/bc.html
# Package: bc-7.0.3.tar.xz
# (1 test-suite command block(s) from the book left out.)

CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r

make

make install

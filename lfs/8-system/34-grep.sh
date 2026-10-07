# LFS 12.4, 8.35. Grep-3.12
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/grep.html
# Package: grep-3.12.tar.xz
# (1 test-suite command block(s) from the book left out.)

sed -i "s/echo/#echo/" src/egrep.sh

./configure --prefix=/usr

make

make install

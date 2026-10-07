# LFS 12.4, 8.31. Sed-4.9
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/sed.html
# Package: sed-4.9.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr

make
make html

make install
install -d -m755           /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9

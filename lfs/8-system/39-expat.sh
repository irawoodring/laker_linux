# LFS 12.4, 8.40. Expat-2.7.1
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/expat.html
# Package: expat-2.7.1.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.7.1

make

make install

install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.1

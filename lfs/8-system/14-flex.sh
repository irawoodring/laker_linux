# LFS 12.4, 8.15. Flex-2.6.4
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/flex.html
# Package: flex-2.6.4.tar.gz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr \
            --docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static

make

make install

ln -sv flex   /usr/bin/lex
ln -sv flex.1 /usr/share/man/man1/lex.1

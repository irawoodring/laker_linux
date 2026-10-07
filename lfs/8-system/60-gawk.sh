# LFS 12.4, 8.61. Gawk-5.3.2
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/gawk.html
# Package: gawk-5.3.2.tar.xz
# (1 test-suite command block(s) from the book left out.)

sed -i 's/extras//' Makefile.in

./configure --prefix=/usr

make

rm -f /usr/bin/gawk-5.3.2
make install

ln -sv gawk.1 /usr/share/man/man1/awk.1

install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.3.2

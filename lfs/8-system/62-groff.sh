# LFS 12.4, 8.63. Groff-1.23.0
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/groff.html
# Package: groff-1.23.0.tar.gz
# (1 test-suite command block(s) from the book left out.)

# LakerLinux: the book's <paper_size> is A4 or letter; US letter here.
PAGE=letter ./configure --prefix=/usr

make

make install

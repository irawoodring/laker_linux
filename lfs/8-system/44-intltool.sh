# LFS 12.4, 8.45. Intltool-0.51.0
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/intltool.html
# Package: intltool-0.51.0.tar.gz
# (1 test-suite command block(s) from the book left out.)

sed -i 's:\\\${:\\\$\\{:' intltool-update.in

./configure --prefix=/usr

make

make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO

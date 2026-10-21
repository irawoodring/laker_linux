# Extra: Fontconfig-2.17.1 (from BLFS 12.4)
# https://www.linuxfromscratch.org/blfs/view/12.4/general/fontconfig.html
# Package: fontconfig-2.17.1.tar.xz
# Optional: GUI=yes
#
# Finds fonts: given a name like "monospace" or "DejaVu Sans:bold", it picks an
# installed font file. foot asks it for every font it uses.

./configure --prefix=/usr        \
            --sysconfdir=/etc    \
            --localstatedir=/var \
            --disable-docs       \
            --docdir=/usr/share/doc/fontconfig-2.17.1 &&
make

make install

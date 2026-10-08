# LFS 12.4, 8.41. Inetutils-2.6
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/inetutils.html
# Package: inetutils-2.6.tar.xz
# (1 test-suite command block(s) from the book left out.)

sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c

./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers

make

make install

mv -v /usr/{,s}bin/ifconfig

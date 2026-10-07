# LFS 12.4, 8.59. Coreutils-9.7
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/coreutils.html
# Package: coreutils-9.7.tar.xz
# (2 test-suite command block(s) from the book left out.)

patch -Np1 -i ../coreutils-9.7-upstream_fix-1.patch

patch -Np1 -i ../coreutils-9.7-i18n-1.patch

autoreconf -fv
automake -af
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime

make

make NON_ROOT_USERNAME=tester check-root

groupadd -g 102 dummy -U tester

groupdel dummy

make install

mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8

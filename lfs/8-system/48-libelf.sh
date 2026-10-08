# LFS 12.4, 8.49. Libelf from Elfutils-0.193
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/libelf.html
# Package: elfutils-0.193.tar.bz2
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr        \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy

make

make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a

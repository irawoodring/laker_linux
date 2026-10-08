# LFS 12.4, 8.17. Expect-5.45.4
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/expect.html
# Package: expect5.45.4.tar.gz
# (1 test-suite command block(s) from the book left out.)

python3 -c 'from pty import spawn; spawn(["echo", "ok"])'

patch -Np1 -i ../expect-5.45.4-gcc15-1.patch

./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include

make

make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib

# LFS 12.4, 8.21. GMP-6.3.0
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/gmp.html
# Package: gmp-6.3.0.tar.xz
# (1 test-suite command block(s) from the book left out.)

# LakerLinux: the book shows "ABI=32 ./configure ..." in a note for 32-bit x86
# systems; it's an example, not a step.

sed -i '/long long t1;/,+1s/()/(...)/' configure

# LakerLinux: the book notes that GMP is tuned for the CPU it's built on, and
# that --host=none-linux-gnu builds a generic one instead. We need the generic
# one: the image runs on other CPUs (QEMU's emulated one, other PCs) than the
# build machine's, and GCC uses GMP, so a tuned GMP makes the compiler die
# with "Illegal instruction" there.
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --host=none-linux-gnu \
            --docdir=/usr/share/doc/gmp-6.3.0

make
make html

# LakerLinux: the book counts the test suite's passes here; tests are skipped.

make install
make install-html

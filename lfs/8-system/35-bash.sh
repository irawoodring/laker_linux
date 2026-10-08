# LFS 12.4, 8.36. Bash-5.3
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/bash.html
# Package: bash-5.3.tar.gz
# (2 test-suite command block(s) from the book left out.)

./configure --prefix=/usr             \
            --without-bash-malloc     \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.3

make

make install

# LakerLinux: the book restarts the shell here (exec /usr/bin/bash --login) to
# start using the new bash. The next script runs in a fresh shell anyway.

# LFS 12.4, 8.26. Libcap-2.76
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/libcap.html
# Package: libcap-2.76.tar.xz
# (1 test-suite command block(s) from the book left out.)

sed -i '/install -m.*STA/d' libcap/Makefile

make prefix=/usr lib=lib

make prefix=/usr lib=lib install

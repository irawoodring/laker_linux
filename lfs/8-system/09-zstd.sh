# LFS 12.4, 8.10. Zstd-1.5.7
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/zstd.html
# Package: zstd-1.5.7.tar.gz
# (1 test-suite command block(s) from the book left out.)

make prefix=/usr

make prefix=/usr install

rm -v /usr/lib/libzstd.a

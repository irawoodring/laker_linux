# LFS 12.4, 8.9. Lz4-1.10.0
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/lz4.html
# Package: lz4-1.10.0.tar.gz

make BUILD_STATIC=no PREFIX=/usr

make -j1 check

make BUILD_STATIC=no PREFIX=/usr install

# LFS 12.4, 6.2. M4-1.4.20
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter06/m4.html
# Package: m4-1.4.20.tar.xz

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

make

make DESTDIR=$LFS install

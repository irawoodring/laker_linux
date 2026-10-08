# LFS 12.4, 6.14. Sed-4.9
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter06/sed.html
# Package: sed-4.9.tar.xz

./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)

make

make DESTDIR=$LFS install

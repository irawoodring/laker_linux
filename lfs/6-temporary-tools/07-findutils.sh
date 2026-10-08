# LFS 12.4, 6.8. Findutils-4.10.0
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter06/findutils.html
# Package: findutils-4.10.0.tar.xz

./configure --prefix=/usr                   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT                 \
            --build=$(build-aux/config.guess)

make

make DESTDIR=$LFS install

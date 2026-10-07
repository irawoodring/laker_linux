# LFS 12.4, 8.48. OpenSSL-3.5.2
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/openssl.html
# Package: openssl-3.5.2.tar.gz
# (1 test-suite command block(s) from the book left out.)

./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic

make

sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install

mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.5.2

cp -vfr doc/* /usr/share/doc/openssl-3.5.2

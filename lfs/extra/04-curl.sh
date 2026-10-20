# Extra: cURL-8.15.0 (from BLFS 12.4)
# https://www.linuxfromscratch.org/blfs/view/12.4/basicnet/curl.html
# Package: curl-8.15.0.tar.xz
#
# Downloads over http(s) and more: the curl command, and libcurl, which git
# uses to talk to servers like GitHub.
# LakerLinux: BLFS recommends libpsl, which LFS doesn't have, so it's left out.
# The certificates that https needs to check servers come from the build
# container (installed by scripts/build.sh as /etc/ssl/certs/ca-certificates.crt)
# instead of BLFS's make-ca. The documentation isn't copied.

./configure --prefix=/usr                                        \
            --disable-static                                     \
            --with-openssl                                       \
            --without-libpsl                                     \
            --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt &&
make

make install

# LFS 12.4, 8.66. IPRoute2-6.16.0
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/iproute2.html
# Package: iproute2-6.16.0.tar.xz

sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8

make NETNS_RUN_DIR=/run/netns

make SBINDIR=/usr/sbin install

install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.16.0

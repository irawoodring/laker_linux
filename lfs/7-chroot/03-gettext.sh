# LFS 12.4, 7.7. Gettext-0.26
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter07/gettext.html
# Package: gettext-0.26.tar.xz

./configure --disable-shared

make

cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

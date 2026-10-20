# Extra: Git-2.50.1 (from BLFS 12.4)
# https://www.linuxfromscratch.org/blfs/view/12.4/general/git.html
# Package: git-2.50.1.tar.xz
#
# Version control. With curl (the step before), it clones over https:
#   git clone https://github.com/irawoodring/laker_linux
# LakerLinux: no documentation (it needs asciidoc and xmlto).

./configure --prefix=/usr                   \
            --with-gitconfig=/etc/gitconfig \
            --with-python=python3 &&
make

make perllibdir=/usr/lib/perl5/5.42/site_perl install

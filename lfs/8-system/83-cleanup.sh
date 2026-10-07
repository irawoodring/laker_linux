# LFS 12.4, 8.85. Cleaning Up
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/cleanup.html
# Package: (none)

# LakerLinux: the book's rm -rf /tmp/{*,.*} also matches . and .., which rm
# refuses to remove (with an error that would stop this script). Same effect:
find /tmp -mindepth 1 -delete

find /usr/lib /usr/libexec -name \*.la -delete

find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf

userdel -r tester

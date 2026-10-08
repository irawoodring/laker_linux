# LFS 12.4, 7.13. Cleaning up and Saving the Temporary System
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter07/cleanup.html
# Package: (none)

rm -rf /usr/share/{info,man,doc}/*

find /usr/{lib,libexec} -name \*.la -delete

rm -rf /tools

# LakerLinux: the book now leaves the chroot, unmounts the virtual file systems
# and makes an optional backup tarball. scripts/lfs.sh handles the chroot
# itself, and skips the backup (rebuilding from the chapter 6 stamps is easier).

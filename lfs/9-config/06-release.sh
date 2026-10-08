# LFS 12.4, 11.1. The End
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter11/theend.html
# Package: (none)
#
# LakerLinux: our own name, built on LFS 12.4.

echo 12.4 > /etc/lfs-release

cat > /etc/lsb-release << "EOF"
DISTRIB_ID="LakerLinux"
DISTRIB_RELEASE="12.4"
DISTRIB_CODENAME="laker"
DISTRIB_DESCRIPTION="LakerLinux (Linux From Scratch 12.4)"
EOF

cat > /etc/os-release << EOF
NAME="LakerLinux"
VERSION="12.4"
ID=lakerlinux
ID_LIKE=lfs
PRETTY_NAME="LakerLinux (LFS 12.4, built $(date +%Y-%m-%d))"
VERSION_CODENAME="laker"
HOME_URL="https://github.com/irawoodring/laker_linux"
EOF

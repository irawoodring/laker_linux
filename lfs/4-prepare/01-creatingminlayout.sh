# LFS 12.4, 4.2. Creating a Limited Directory Layout in the LFS Filesystem
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter04/creatingminlayout.html
# Package: (none)

mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

for i in bin lib sbin; do
  ln -sv usr/$i $LFS/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac

mkdir -pv $LFS/tools

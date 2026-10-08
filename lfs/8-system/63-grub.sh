# LFS 12.4, 8.64. GRUB-2.12
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/grub.html
# Package: grub-2.12.tar.xz
# Skip: LakerLinux boots the kernel straight from UEFI firmware, without a
#   bootloader (see "How it boots" in README.md). Delete this line to build GRUB.

unset {C,CPP,CXX,LD}FLAGS

echo depends bli part_gpt > grub-core/extra_deps.lst

./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-efiemu  \
            --disable-werror

make

make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions

# Extra: XKeyboard-Config-2.45 (from BLFS 12.4)
# https://www.linuxfromscratch.org/blfs/view/12.4/x/xkeyboard-config.html
# Package: xkeyboard-config-2.45.tar.xz
# Optional: GUI=yes
#
# The keyboard layout database: for every layout (us, de, fr dvorak, ...), what
# each key produces. libxkbcommon reads it at run time.
# LakerLinux: BLFS lists the Xorg libraries as required and installs into
# $XORG_PREFIX. The meson build needs neither, so this goes straight into /usr.

mkdir build &&
cd    build &&

meson setup --prefix=/usr --buildtype=release .. &&
ninja

ninja install

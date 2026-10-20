# Extra: FreeType-2.13.3 (from BLFS 12.4)
# https://www.linuxfromscratch.org/blfs/view/12.4/general/freetype2.html
# Package: freetype-2.13.3.tar.xz
# Optional: GUI=yes
#
# Turns TrueType/OpenType font files into glyph images. foot uses it, and so
# does pane: built after this, pane draws its titles and menus in real fonts.
# LakerLinux: BLFS recommends HarfBuzz (a circular dependency: FreeType, then
# HarfBuzz, then FreeType again) and libpng; neither is here, so FreeType
# builds without them.

sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg &&

sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
    -i include/freetype/config/ftoption.h  &&

./configure --prefix=/usr --enable-freetype-config --disable-static &&
make

make install

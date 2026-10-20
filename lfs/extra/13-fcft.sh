# Extra: fcft-3.3.3 (not in BLFS)
# https://codeberg.org/dnkl/fcft
# Package: fcft-3.3.3.tar.gz
# Optional: GUI=yes
#
# foot's font library: loads fonts with Fontconfig and FreeType, and renders
# and caches glyphs into Pixman images.
# LakerLinux: text shaping needs HarfBuzz and utf8proc, which aren't here, so
# it's off (ligatures and complex scripts won't combine). No documentation:
# it needs scdoc.

mkdir build &&
cd    build &&

meson setup ..                          \
      --prefix=/usr                     \
      --buildtype=release               \
      -D docs=disabled                  \
      -D grapheme-shaping=disabled      \
      -D run-shaping=disabled           \
      -D test-text-shaping=false &&
ninja

ninja install

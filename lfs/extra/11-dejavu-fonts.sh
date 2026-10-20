# Extra: DejaVu fonts 2.37 (see BLFS 12.4, "TTF and OTF fonts")
# https://www.linuxfromscratch.org/blfs/view/12.4/x/TTF-and-OTF-fonts.html
# Package: dejavu-fonts-ttf-2.37.tar.bz2
# Optional: GUI=yes
#
# The fonts: DejaVu Sans, Serif and Sans Mono. Fontconfig's default settings
# already prefer them for "sans-serif", "serif" and "monospace", which is what
# foot and pane's theme ask for.

install -v -d -m755 /usr/share/fonts/dejavu
install -v -m644 ttf/*.ttf /usr/share/fonts/dejavu
fc-cache -v /usr/share/fonts/dejavu

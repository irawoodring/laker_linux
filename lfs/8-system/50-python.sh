# LFS 12.4, 8.51. Python-3.13.7
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter08/python.html
# Package: Python-3.13.7.tar.xz
# (1 test-suite command block(s) from the book left out.)

./configure --prefix=/usr          \
            --enable-shared        \
            --with-system-expat    \
            --enable-optimizations \
            --without-static-libpython

make

make install

cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF

install -v -dm755 /usr/share/doc/python-3.13.7/html

tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.13.7/html \
    -xvf ../python-3.13.7-docs-html.tar.bz2

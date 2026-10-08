# LFS 12.4, 9.5. General Network Configuration
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter09/network.html
# Package: (none)
#
# LakerLinux: the book's example addresses are replaced with the fixed ones
# QEMU's user-mode network uses: LakerLinux is 10.0.2.15, the gateway (your
# computer) is 10.0.2.2, and the DNS server is 10.0.2.3. On real hardware,
# change these (or install a DHCP client such as dhcpcd, from BLFS).
# The interface is called eth0 because the kernel command line has
# net.ifnames=0 (see config/versions.sh).

cd /etc/sysconfig/
cat > ifconfig.eth0 << "EOF"
ONBOOT=yes
IFACE=eth0
SERVICE=ipv4-static
IP=10.0.2.15
GATEWAY=10.0.2.2
PREFIX=24
BROADCAST=10.0.2.255
EOF

cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf

nameserver 10.0.2.3

# End /etc/resolv.conf
EOF

echo "lakerlinux" > /etc/hostname

cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost.localdomain localhost
127.0.1.1 lakerlinux.localdomain lakerlinux
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF

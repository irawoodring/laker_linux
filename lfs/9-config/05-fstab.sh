# LFS 12.4, 10.2. Creating the /etc/fstab File
# https://www.linuxfromscratch.org/lfs/view/12.4/chapter10/fstab.html
# Package: (none)
#
# LakerLinux: the root file system is found by its partition UUID
# (config/versions.sh), so this works whatever the disk is called (/dev/vda in
# QEMU, /dev/sda or /dev/nvme0n1 on real machines). laker-install changes it
# to the new partition's UUID on the disks it installs to. There's no swap
# partition.

cat > /etc/fstab << EOF
# Begin /etc/fstab

# file system  mount-point    type     options             dump  fsck
#                                                                order

PARTUUID=$ROOT_PARTUUID /     ext4     defaults            1     1
proc           /proc          proc     nosuid,noexec,nodev 0     0
sysfs          /sys           sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts       devpts   gid=5,mode=620      0     0
tmpfs          /run           tmpfs    defaults            0     0
devtmpfs       /dev           devtmpfs mode=0755,nosuid    0     0
tmpfs          /dev/shm       tmpfs    nosuid,nodev        0     0
cgroup2        /sys/fs/cgroup cgroup2  nosuid,noexec,nodev 0     0

# End /etc/fstab
EOF

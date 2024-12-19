#! /bin/bash
set -ex

# Clean Output Directory
rm -rf /output/*

# Create and Format Root Filesystem Image
truncate -s 2G /output/image.ext4
mkfs.ext4 /output/image.ext4

# Mount the Rootfs
mount /output/image.ext4 /rootfs

# Bootstrap the Base Ubuntu System with "noble" Release
debootstrap --include=openssh-server,unzip,rsync,apt,netplan.io,vim,ca-certificates,curl,bash-completion,htop,less,net-tools,iproute2,wget,gnupg noble /rootfs http://archive.ubuntu.com/ubuntu/

mount --bind / /rootfs/mnt
chroot /rootfs /bin/bash /mnt/script/provision.sh

umount /rootfs/mnt
umount /rootfs

# Package the Rootfs and Kernel
cd /output
tar czvf ubuntu-noble.tar.gz image.ext4
cd /

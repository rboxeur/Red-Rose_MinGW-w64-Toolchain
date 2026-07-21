
export CHROOT_PATH="/opt/chroots/bionic64_chroot_mingw-w64"

echo "Unmount chroot directories. Just in case."
umount -Rl "${CHROOT_PATH}"

echo "Mount directories for chroot"
mount --bind "${CHROOT_PATH}" "${CHROOT_PATH}"
mount -t proc /proc "${CHROOT_PATH}"/proc
mount --bind /sys "${CHROOT_PATH}"/sys
mount --make-rslave "${CHROOT_PATH}"/sys
mount --bind /dev "${CHROOT_PATH}"/dev
mount --bind /dev/pts "${CHROOT_PATH}"/dev/pts
mount --bind /dev/shm "${CHROOT_PATH}"/dev/shm
#mount --bind /opt/Sources/Build_MinGW-Experimental/ "${CHROOT_PATH}"/opt/Sources/Build_MinGW-Experimental/
mount --make-rslave "${CHROOT_PATH}"/dev

rm -f "${CHROOT_PATH}"/etc/resolv.conf
cp /etc/resolv.conf "${CHROOT_PATH}"/etc/resolv.conf


echo "Chrooting into ${CHROOT_PATH}"
chroot "${CHROOT_PATH}" /usr/bin/env LANG=en_US.UTF-8 TERM=xterm PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/loca/bin" /bin/bash

echo "Unmount chroot directories"
#umount -l "${CHROOT_PATH}"/opt/Sources/Build_MinGW-Experimental/
umount -l "${CHROOT_PATH}"
umount "${CHROOT_PATH}"/proc
umount "${CHROOT_PATH}"/sys
umount "${CHROOT_PATH}"/dev/pts
umount "${CHROOT_PATH}"/dev/shm
umount "${CHROOT_PATH}"/dev

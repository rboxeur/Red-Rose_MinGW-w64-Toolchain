#!/usr/bin/env bash

## A script for creating Ubuntu bootstraps for Wine compilation.
##
## debootstrap and perl are required
## root rights are required
##
## About 5.5 GB of free space is required
## And additional 2.5 GB is required for Wine compilation

if [ "$EUID" != 0 ]; then
	echo "This script requires root rights!"
	exit 1
fi

if ! command -v debootstrap 1>/dev/null || ! command -v perl 1>/dev/null; then
	echo "Please install debootstrap and perl and run the script again"
	exit 1
fi

# Keep in mind that although you can choose any version of Ubuntu/Debian
# here, but this script has only been tested with Ubuntu 18.04 Bionic
export CHROOT_DISTRO="bionic"
# France: choose the one below
export CHROOT_MIRROR="https://bouyguestelecom.ubuntu.lafibre.info/ubuntu/"

# Set your preferred path for storing chroots
# Also don't forget to change the path to the chroots in the build_wine.sh
# script, if you are going to use it
export MAINDIR=/opt/chroots
export CHROOT_X64="${MAINDIR}"/${CHROOT_DISTRO}64_chroot_mingw-w64

prepare_chroot () {
	CHROOT_PATH="${CHROOT_X64}"

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
	mount --make-rslave "${CHROOT_PATH}"/dev

	rm -f "${CHROOT_PATH}"/etc/resolv.conf
	cp /etc/resolv.conf "${CHROOT_PATH}"/etc/resolv.conf

	echo "Chrooting into ${CHROOT_PATH}"
	chroot "${CHROOT_PATH}" /usr/bin/env LANG=en_US.UTF-8 TERM=xterm PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/RosBE/bin" /opt/prepare_chroot.sh

	echo "Unmount chroot directories"
	umount -l "${CHROOT_PATH}"
	umount "${CHROOT_PATH}"/proc
	umount "${CHROOT_PATH}"/sys
	umount "${CHROOT_PATH}"/dev/pts
	umount "${CHROOT_PATH}"/dev/shm
	umount "${CHROOT_PATH}"/dev
}

create_build_scripts () {
	cat <<EOF > "${MAINDIR}"/prepare_chroot.sh
#!/bin/bash

apt-get update
apt-get -y install nano
apt-get -y install locales
echo ru_RU.UTF_8 UTF-8 >> /etc/locale.gen
echo en_US.UTF_8 UTF-8 >> /etc/locale.gen
locale-gen
echo deb '${CHROOT_MIRROR}' ${CHROOT_DISTRO} main universe > /etc/apt/sources.list
echo deb '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-updates main universe >> /etc/apt/sources.list
echo deb '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-security main universe >> /etc/apt/sources.list
echo deb-src '${CHROOT_MIRROR}' ${CHROOT_DISTRO} main universe >> /etc/apt/sources.list
echo deb-src '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-updates main universe >> /etc/apt/sources.list
echo deb-src '${CHROOT_MIRROR}' ${CHROOT_DISTRO}-security main universe >> /etc/apt/sources.list

sort -u /etc/apt/sources.list > /tmp/sources.list && mv /tmp/sources.list /etc/apt/sources.list


function install_buildenv() {
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	apt-get -y upgrade
	apt-get -y dist-upgrade
	apt-get -y install software-properties-common
	add-apt-repository -y ppa:ubuntu-toolchain-r/test
	add-apt-repository -y ppa:cybermax-dexter/mingw-w64-backport
	apt-get update
	apt-get -y install ccache gcc-11 g++-11 wget git gcc-mingw-w64 g++-mingw-w64 vim m4 texinfo bison flex make zlib1g-dev autoconf libzstd-dev automake libtool time

	vers=11; update-alternatives \
  	--install /usr/bin/gcc gcc /usr/bin/gcc-"\${vers}" "\${vers}"0 \
  	--slave /usr/bin/x86_64-linux-gnu-gcc x86_64-linux-gnu-gcc /usr/bin/x86_64-linux-gnu-gcc-"\${vers}" \
  	--slave /usr/bin/g++ g++ /usr/bin/g++-"\${vers}" \
  	--slave /usr/bin/x86_64-linux-gnu-g++ x86_64-linux-gnu-g++ /usr/bin/x86_64-linux-gnu-g++-"\${vers}" \
  	--slave /usr/bin/x86_64-linux-gnu-cpp x86_64-linux-gnu-cpp /usr/bin/x86_64-linux-gnu-cpp-"\${vers}" \
  	--slave /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-"\${vers}" \
  	--slave /usr/bin/x86_64-linux-gnu-gcc-ar x86_64-linux-gnu-gcc-ar /usr/bin/x86_64-linux-gnu-gcc-ar-"\${vers}" \
  	--slave /usr/bin/gcc-nm gcc-nm /usr/bin/gcc-nm-"\${vers}" \
  	--slave /usr/bin/x86_64-linux-gnu-gcc-nm x86_64-linux-gnu-gcc-nm /usr/bin/x86_64-linux-gnu-gcc-nm-"\${vers}" \
  	--slave /usr/bin/gcc-ranlib gcc-ranlib /usr/bin/gcc-ranlib-"\${vers}" \
  	--slave /usr/bin/x86_64-linux-gnu-gcc-ranlib x86_64-linux-gnu-gcc-ranlib /usr/bin/x86_64-linux-gnu-gcc-ranlib-"\${vers}" \
  	--slave /usr/bin/gcov gcov /usr/bin/gcov-"\${vers}" \
  	--slave /usr/bin/x86_64-linux-gnu-gcov x86_64-linux-gnu-gcov /usr/bin/x86_64-linux-gnu-gcov-"\${vers}" \
  	--slave /usr/bin/gcov-dump gcov-dump /usr/bin/gcov-dump-"\${vers}" \
  	--slave /usr/bin/x86_64-linux-gnu-gcov-dump x86_64-linux-gnu-gcov-dump /usr/bin/x86_64-linux-gnu-gcov-dump-"\${vers}" \
  	--slave /usr/bin/gcov-tool gcov-tool /usr/bin/gcov-tool-"\${vers}" \
  	--slave /usr/bin/x86_64-linux-gnu-gcov-tool x86_64-linux-gnu-gcov-tool /usr/bin/x86_64-linux-gnu-gcov-tool-"\${vers}" \
  	--slave /usr/bin/lto-dump lto-dump /usr/bin/lto-dump-"\${vers}" \
  	--slave /usr/bin/x86_64-linux-gnu-lto-dump x86_64-linux-gnu-lto-dump /usr/bin/x86_64-linux-gnu-lto-dump-"\${vers}"
}

install_buildenv

EOF

	chmod +x "${MAINDIR}"/prepare_chroot.sh
	cp "${MAINDIR}"/prepare_chroot.sh "${CHROOT_X32}"/opt
	mv "${MAINDIR}"/prepare_chroot.sh "${CHROOT_X64}"/opt
}

mkdir -p "${MAINDIR}"

debootstrap --arch amd64 $CHROOT_DISTRO "${CHROOT_X64}" $CHROOT_MIRROR

create_build_scripts

prepare_chroot > "${CHROOT_X64}"/opt/prepare_chroot.log 2>&1

#rm "${CHROOT_X64}"/opt/prepare_chroot.sh

clear
echo "Done"

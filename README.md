# Red-Rose_MinGW-w64-Toolchain

This is the MinGW-w64 Toolchain I use to build Wine inside my 2 chroots (32 Bits and 64 Bits).

## About
Experimental Canadian Cross-Compilation Toolchain on linux

- Gcc: version = 11.50 already patched
- Binutils: version = 2.38 already patched
- MinGW-w64: version = 14.0.0.r220.gd999af622, commit = d999af62247693a8b5b25a98d67316c8bb2dcd37 refreshed base on Wine upstream

with

- Thread model: posix
- Ucrt instead of msvcrt
- target architectures: 32 Bits and 64 Bits
- all binairies are built statically

built inside a Ubuntu 18.04 chroot to make it portable

## How to use

Download and decompress the tarball

```bash
release=14.0.0.r220.gd999af622
wget https://github.com/rboxeur/Red-Rose_MinGW-w64-Toolchain/releases/download/${release}/Red-Rose-MinGW-w64-Posix-Ucrt-v${release}-Gcc-11.5.0.tar.xz
sudo tar xf Red-Rose-MinGW-w64-Posix-Ucrt-v${release}-Gcc-11.5.0.tar.xz -C /
```
Point to its binairies by modifying your PATH environment variable

```bash
export release=14.0.0.r220.gd999af622
export PATH=/opt/Red-Rose-MinGW-w64-Posix-Ucrt-v${release}-Gcc-11.5.0/bin/:${PATH}
```

## Information regarding  Binutils 2.38 and Gcc 11.5.0

### Binutils 2.38
Binutils 2.38 is patched against Linux and MinGW-w64 patches and is provided with original packages

- GMP: 6.3.0
- MPC: 1.3.1
- MPFR: 4.2.1
- ISL: 0.22.1

### Gcc 11.5.0
Gcc 11.5.0 is patched against Linux and MinGW-w64 patches and is provided with fresh packages

- GMP: repo = https://gmplib.org/repo/gmp/, changeset = 18494:7ff7050d24e
- MPC: repo = https://github.com/BrianGladman/mpc.git, commit = d34d34127794cbbd7f24f58d175fa139172c1644
- MPFR: repo = https://gitlab.inria.fr/mpfr/mpfr.git, commit = 94e041204f1f997ad76e8e5e53ea022ac484b67a
- ISL: repo = https://github.com/Meinersbur/isl.git, commit = dc16f8e3d62c9e808ef86ffe82c2b93ac1446da3

Some headers files (.h) for packages are refreshed too.

## How to build on your own?

### 1. Clone the repository

Based on your needs, you need fron 7.0 GB to 8.00 GB as free space to build the toolchain

```bash
git clone https://github.com/rboxeur/Red-Rose_MinGW-w64-Toolchain.git
```

### Prepare the environment based on your own needs and the target CPU host
- Edit the file ``create_ubuntu_18.04_bootstraps_mingw-w64.sh`` using your favorite text editor (nano, vim...)
- Replace this line

```bash
export MAINDIR=/opt/chroots
```

by your own choice. This is the target folder where your Ubuntu 18.04 chroot will be located. Keep it as it if it's ok for you

Pay attention that if you modified this script then you have to do the same for  ``chroot-on-bionic64-mingw-w64.sh``

```bash
export CHROOT_PATH="/opt/chroots/bionic64_chroot_mingw-w64"
```

- Save your choice and lauch it

``` bash
sudo chmod +x create_ubuntu_18.04_bootstraps_mingw-w64.sh
sudo ./create_ubuntu_18.04_bootstraps_mingw-w64.sh
```

- Once chroot is ready then 
- Edit the file ``build-mingw-w64-toolchain-inside-chroot.sh`` and replace the line with your own CPU flags.

```bash
export OPTIMIZE_FLAGS="..."
```
- Save your changes.
- Copy folder ``sources`` and script ``build-mingw-w64-toolchain-inside-chroot.sh``

```
sudo cp -rf sources /opt/chroots/bionic64_chroot_mingw-w64/root/
sudo cp build-mingw-w64-toolchain-inside-chroot.sh /opt/chroots/bionic64_chroot_mingw-w64/root/
```

- Launch the script ``chroot-on-bionic64-mingw-w64.sh``

Now you are inside the chroot and ready to build the toolchain

```bash

release=$(grep ^MINGW_W64_PKGVER build-mingw-w64-toolchain-inside-chroot.sh | awk -F '=' '{print $NF;}'|sed -e "s:\"::g")

cd

chmod +x build-mingw-w64-toolchain-inside-chroot.sh 

./build-mingw-w64-toolchain-inside-chroot.sh /opt/Red-Rose-MinGW-w64-Posix-Ucrt-v${release}-Gcc-11.5.0/
```

Based on your CPU this step could take some times!!!

Your toolchain is ready. Optionaly you could compress it

```bash
release=$(grep ^MINGW_W64_PKGVER build-mingw-w64-toolchain-inside-chroot.sh | awk -F '=' '{print $NF;}'|sed -e "s:\"::g")

cd

XZ_OPT="-9e -T0" tar chvJf Red-Rose-MinGW-w64-Posix-Ucrt-v${release}-Gcc-11.5.0.tar.xz /opt/Red-Rose-MinGW-w64-Posix-Ucrt-v${release}-Gcc-11.5.0
```

You can quit the chroot (command exit) and use your toolchain on the target host.

Congratulations. Have fun

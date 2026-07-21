# Red-Rose_MinGW-w64-Toolchain

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
curl https://github.com/rboxeur/Red-Rose_MinGW-w64-Toolchain/releases/download/${release}/Red-Rose-MinGW-w64-Posix-Ucrt-v${release}-Gcc-11.5.0.tar.xz --output Red-Rose-MinGW-w64-Posix-Ucrt-v${release}-Gcc-11.5.0.tar.xz
sudo tar xf Red-Rose-MinGW-w64-Posix-Ucrt-v14.0.0.r220.gd999af622-Gcc-11.5.0.tar.xz -C /
```
Point to its binairies by modifying your PATH environment variable

```bash
export release=14.0.0.r220.gd999af622
export PATH=/opt/Red-Rose-MinGW-w64-Posix-Ucrt-v${release}-Gcc-11.5.0/bin/:${PATH}
```

## Information regarding  Binutils 2.38 and Gcc 11.5.0

Binutils 2.38 is patched against Linux and MinGW-w64 patches and is provided with

- GMP: 6.3.0
- MPC: 1.3.1
- MPFR: 4.2.1
- ISL: 0.22.1

Gcc 11.5.0 is patched against Linux and MinGW-w64 patches and is provided with

- GMP: repo = https://gmplib.org/repo/gmp/, changeset = 18494:7ff7050d24e
- MPC: repo = https://github.com/BrianGladman/mpc.git, commit = d34d34127794cbbd7f24f58d175fa139172c1644
- MPFR: repo = https://gitlab.inria.fr/mpfr/mpfr.git, commit = 94e041204f1f997ad76e8e5e53ea022ac484b67a
- ISL: repo = https://github.com/Meinersbur/isl.git, commit = dc16f8e3d62c9e808ef86ffe82c2b93ac1446da3


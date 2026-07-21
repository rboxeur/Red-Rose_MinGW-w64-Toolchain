#!/bin/bash
set -e

# Flags I use for my remote CPU = Ryzen 4600 H
# Replace with your own flags if needed
export OPTIMIZE_FLAGS=" -O3 -march=znver2 -mmmx -mpopcnt -msse -msse2 -msse3 -mssse3 -msse4.1 -msse4.2 -mavx -mavx2 -msse4a -mfma -mbmi -mbmi2 -maes -mpclmul -madx -mabm -mclflushopt -mclwb -mclzero -mcx16 -mf16c -mfsgsbase -mfxsr -msahf -mlzcnt -mmovbe -mmwaitx -mprfchw -mrdpid -mrdrnd -mrdseed -msha -mwbnoinvd -mxsave -mxsavec -mxsaveopt -mxsaves --param l1-cache-size=32 --param l1-cache-line-size=64 --param l2-cache-size=512 -mtune=znver2 -fasynchronous-unwind-tables -Wformat -Wformat-security -dumpbase - -pipe  "
export SANITY_FLAGS=" -mfpmath=sse -fwrapv -fno-strict-aliasing "
export COMMON_FLAGS=" ${OPTIMIZE_FLAGS} ${SANITY_FLAGS} "

export CFLAGS32=" ${COMMON_FLAGS} -mstackrealign -fno-stack-protector "
export CFLAGS64=" ${COMMON_FLAGS} -mcmodel=small -fno-stack-protector "

if [ -z "$1" ]; then
    echo "Makes a local build of mingw-w64 in this directory and installs it to the given path."
    echo ""
    echo "Note: Requires a system mingw-w64 compiler to be present already on your build machine, for us to bootstrap with."
    echo ""
    echo "usage:"
    echo -e "\t$0 <installation path e.g. \$HOME/.local>"
    exit 1
fi

if [ -z "$MAKEFLAGS" ]; then
    JOBS=-j$(($(nproc) - 1))
fi

DST_DIR="$1"

BINUTILS_VER="2.38.r183.g4d71e17a9fd"
BINUTILS_SRCDIR=binutils-$BINUTILS_VER

GCC_VER=11.5.0
GCC_SRCDIR=gcc-$GCC_VER

MINGW_W64_PKGVER="14.0.0.r220.gd999af622"
MINGW_W64_GITVER="03d8a40f57649fbb773f1cdbe3a760f5e0943e76"
MINGW_W64_GITURL="https://github.com/mingw-w64/mingw-w64.git" 
MINGW_W64_SRCDIR=mingw-w64-git

cd sources

tar xf gcc-11.5.0-patched.tar.xz
tar xf mingw-w64-git-${MINGW_W64_PKGVER}.tar.xz 
tar xf pkgconf-2.5.1.tar.xz
tar xf binutils-2.38.r183.g4d71e17a9fd-patched.tar.xz 
tar xf mingw64-x86_64-windows-default-manifest-6.4-1-src.tar.xz && cd mingw64-x86_64-windows-default-manifest-6.4-1.src/ && tar xf windows-default-manifest-6.4.tar.bz2 && cd ..


function build_arch {
    BUILD_ARCH=$(gcc -dumpmachine) #machine which is building the compiler
    HOST_ARCH=$1 #machine which will run the compiler
    WIN32_TARGET_ARCH=$2 #machine which we are building for
    NEWPATH=$DST_DIR/bin:$PATH

    if [ ${WIN32_TARGET_ARCH} == "i686-w64-mingw32" ];then
        export CFLAGS="${CFLAGS32} -fPIC -fno-lto "
    fi
    
    if [ ${WIN32_TARGET_ARCH} == "x86_64-w64-mingw32" ];then
        export CFLAGS="${CFLAGS64} -fPIC -fno-lto "
    fi   

    export CXXFLAGS="${CFLAGS} -std=c++11 -fPIC -fno-lto "
    export CPPFLAGS="${CFLAGS} -fPIC -fno-lto "

    mkdir -p build-$WIN32_TARGET_ARCH/
    pushd build-$WIN32_TARGET_ARCH/

        mkdir -p binutils/
        pushd binutils/
            if [ ! -e Makefile ]; then
                    ../../$BINUTILS_SRCDIR/configure \
                    --prefix=$DST_DIR/ \
                    --build=$BUILD_ARCH \
                    --host=$HOST_ARCH \
                    --target=$WIN32_TARGET_ARCH \
                    --enable-lto \
                    --enable-deterministic-archives \
                    --disable-multilib \
                    --disable-nls \
                    --disable-werror \
                    --with-pkgversion="Red-Rose-MinGW-w64-Posix-Ucrt-${MINGW_W64_PKGVER}" \
                    --with-bugurl="https://github.com/rboxeur/Red-Rose_MinGW-w64-Toolchain/" \
                    $BINUTILS_EXTRA_CONFIGURE
            fi
            make $JOBS configure-host
            make $JOBS LDFLAGS=-all-static
            make $JOBS install-strip
        popd

        # Build manifest
        mkdir -p mingw-w64-windows-default-manifest/
        pushd mingw-w64-windows-default-manifest/
            if [ ! -e Makefile ]; then
                    PATH=$NEWPATH:$PATH ../../mingw64-x86_64-windows-default-manifest-6.4-1.src/windows-default-manifest/configure \
                    --prefix=$DST_DIR/$WIN32_TARGET_ARCH/ \
                    --build=$BUILD_ARCH \
                    --host=$WIN32_TARGET_ARCH \
                    --target=$WIN32_TARGET_ARCH
            fi
            PATH=$NEWPATH make $JOBS install
        popd
        # End Build manifest  

        # For below -with-default-win32-winnt, please refer to this page: https://learn.microsoft.com/fr-fr/cpp/porting/modifying-winver-and-win32-winnt?view=msvc-170

        mkdir -p mingw-w64-headers/
        pushd mingw-w64-headers/
            if [ ! -e Makefile ]; then
                PATH=$NEWPATH:$PATH ../../$MINGW_W64_SRCDIR/mingw-w64-headers/configure \
                    --prefix=$DST_DIR/$WIN32_TARGET_ARCH/ \
                    --host=$WIN32_TARGET_ARCH \
                    --enable-sdk=all \
                    --enable-secure-api \
                    --enable-idl \
                    --enable-crt \
                    --with-default-msvcrt=ucrt \
                    --with-default-win32-winnt="0xa00" \
                    $MINGW_W64_HEADERS_EXTRA_CONFIGURE
            fi
            PATH=$NEWPATH:$PATH make $JOBS install
        popd      

        export lt_cv_deplibs_check_method='pass_all'

        mkdir -p gcc/
        pushd gcc/
            if [ ! -e Makefile ]; then
                #arguments mostly taken from Arch AUR mingw-w64-gcc PKGBUILD,
                #except "--disable-dw2-exceptions" swapped for "--disable-sjlj-exceptions --with-dwarf2"
                #for performance reasons on 32-bit
                LDFLAGS=-static PATH=$NEWPATH:$PATH ../../$GCC_SRCDIR/configure \
                    --prefix=$DST_DIR/ \
                    --build=$BUILD_ARCH \
                    --host=$HOST_ARCH \
                    --target=$WIN32_TARGET_ARCH \
                    --with-pkgversion="Red-Rose-MinGW-w64-Posix-Ucrt-${MINGW_W64_PKGVER}" \
                    --with-bugurl="https://github.com/rboxeur/Red-Rose_MinGW-w64-Toolchain/" \
                    $GCC_EXTRA_CONFIGURE
            fi
            PATH=$NEWPATH make $JOBS all-gcc
            PATH=$NEWPATH make $JOBS install-strip-gcc
        popd

        mkdir -p mingw-w64-crt/
        pushd mingw-w64-crt/
            if [ ! -e Makefile ]; then
                PATH=$NEWPATH ../../$MINGW_W64_SRCDIR/mingw-w64-crt/configure \
                    --prefix=$DST_DIR/$WIN32_TARGET_ARCH/ \
                    --host=$WIN32_TARGET_ARCH \
                    --enable-wildcard \
                    --enable-private-exports \
                    --enable-delay-import-libs \
                    --enable-experimental=all,dfp,printf128,registeredprintf \
                    --with-default-msvcrt=ucrt \
                    --enable-tests-unicode \
                    $MINGW_W64_CRT_EXTRA_CONFIGURE
            fi
            PATH=$NEWPATH make $JOBS
            PATH=$NEWPATH make $JOBS install
        popd

        mkdir -p mingw-w64-winpthreads/
        pushd mingw-w64-winpthreads/
            if [ ! -e Makefile ]; then
                PATH=$NEWPATH ../../$MINGW_W64_SRCDIR/mingw-w64-libraries/winpthreads/configure \
                    --prefix=$DST_DIR/$WIN32_TARGET_ARCH/ \
                    --host=$WIN32_TARGET_ARCH \
                    --enable-static \
                    --enable-shared \
                    $MINGW_W64_WINPTHREADS_EXTRA_CONFIGURE
            fi
            PATH=$NEWPATH make $JOBS
            PATH=$NEWPATH make $JOBS install
        popd

        pushd gcc/
            #next step requires libgcc in default library location, but
            #"canadian" build doesn't handle that(?), so install it explicitly
            PATH=$NEWPATH make configure-target-libgcc
            PATH=$NEWPATH make -C $WIN32_TARGET_ARCH/libgcc $JOBS
            PATH=$NEWPATH make -C $WIN32_TARGET_ARCH/libgcc $JOBS install-strip

            #install libstdc++ and other stuff
            PATH=$NEWPATH make $JOBS
            PATH=$NEWPATH make $JOBS install-strip

            #libstdc++ requires that libstdc++ is installed in order to find gettimeofday(???)
            #so, rebuild libstdc++ after installing it above
            PATH=$NEWPATH make $JOBS -C $WIN32_TARGET_ARCH/libstdc++-v3/ distclean
            PATH=$NEWPATH make $JOBS 
            PATH=$NEWPATH make $JOBS install-strip
        popd

        for library in libmangle winstorecompat
        do
            mkdir -p mingw-w64-${library}/
            pushd mingw-w64-${library}/
                if [ ! -e Makefile ]; then
                    PATH=$NEWPATH ../../$MINGW_W64_SRCDIR/mingw-w64-libraries/${library}/configure \
                        --prefix=$DST_DIR/$WIN32_TARGET_ARCH/ \
                        --host=$WIN32_TARGET_ARCH \
                        --enable-static \
                        --enable-shared \
                        --bindir=$DST_DIR/bin --program-prefix="${WIN32_TARGET_ARCH}-" \
                        $MINGW_W64_WINPTHREADS_EXTRA_CONFIGURE
                fi
                PATH=$NEWPATH make $JOBS
                PATH=$NEWPATH make $JOBS install
            popd
        done

        #pseh => Only x86 32-bit Win32 host variants are supported
        if [ ${WIN32_TARGET_ARCH} == "i686-w64-mingw32" ];then 
            library="pseh"
            mkdir -p mingw-w64-${library}/
            pushd mingw-w64-${library}/
                if [ ! -e Makefile ]; then
                    PATH=$NEWPATH ../../$MINGW_W64_SRCDIR/mingw-w64-libraries/${library}/configure \
                        --prefix=$DST_DIR/$WIN32_TARGET_ARCH/ \
                        --host=$WIN32_TARGET_ARCH \
                        --enable-static \
                        --enable-shared \
                        --bindir=$DST_DIR/bin --program-prefix="${WIN32_TARGET_ARCH}-" \
                        $MINGW_W64_WINPTHREADS_EXTRA_CONFIGURE
                fi
                PATH=$NEWPATH make $JOBS LDFLAGS=--static
                PATH=$NEWPATH make $JOBS install
            popd            
        fi

        for tools in gendef  genidl  genpeimg  widl
        do
            mkdir -p mingw-w64-tools/${tools}
            pushd mingw-w64-tools/${tools}/
                if [ ! -e Makefile ]; then
                    PATH=$NEWPATH ../../../$MINGW_W64_SRCDIR/mingw-w64-tools/${tools}/configure \
                        --prefix=$DST_DIR/$WIN32_TARGET_ARCH/ \
                        --target=$WIN32_TARGET_ARCH \
                        --bindir=$DST_DIR/bin --program-prefix="${WIN32_TARGET_ARCH}-"
                fi
                PATH=$NEWPATH make $JOBS LDFLAGS=--static
                PATH=$NEWPATH make $JOBS install
            popd
        done

        mkdir -p mingw-w64-pkgconf-config
        pushd mingw-w64-pkgconf-config
        PATH=$NEWPATH LDFLAGS=--static ../../pkgconf-2.5.1/configure \
            --prefix=$DST_DIR/$WIN32_TARGET_ARCH  \
            --target=$WIN32_TARGET_ARCH \
            --bindir=$DST_DIR/bin \
            --with-pkg-config-dir=$DST_DIR/$WIN32_TARGET_ARCH/lib/pkgconfig \
            --enable-static --disable-shared --with-system-includedir=$DST_DIR/$WIN32_TARGET_ARCH/include \
            --with-system-libdir=$DST_DIR/$WIN32_TARGET_ARCH/lib \
            --program-prefix="${WIN32_TARGET_ARCH}-" --program-suffix="-config"
         PATH=$NEWPATH make $JOBS LDFLAGS=--static
         PATH=$NEWPATH make $JOBS install && { cp $DST_DIR/bin/${WIN32_TARGET_ARCH}-pkgconf-config  $DST_DIR/bin/${WIN32_TARGET_ARCH}-pkg-config; }
         popd

    popd

    # Free up / Clean up 
    ${WIN32_TARGET_ARCH}-strip ${DST_DIR}/${WIN32_TARGET_ARCH}/lib/*.dll
    strip ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-*
    strip ${DST_DIR}/lib/gcc/${WIN32_TARGET_ARCH}/11.5.0/{cc1*,collect2,lto*}
    mv ${DST_DIR}/${WIN32_TARGET_ARCH}/lib/*.dll ${DST_DIR}/${WIN32_TARGET_ARCH}/bin/
    #rm -rf ${DST_DIR}/share/*

cat << _EOF_ > ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-configure

export CFLAGS="${CFLAGS}-fPIC -fno-lto "
export CXXFLAGS="${CFLAGS} -std=c++11 -fPIC -fno-lto "
export CPPFLAGS="${CFLAGS} -fPIC -fno-lto "
export LDFLAGS=" -Wl,-O1,--sort-common,--as-needed -Wl,--file-alignment,4096 -Wl,--export-all-symbols -Wl,--enable-auto-import -static-libgcc  -static-libstdc++ -fasynchronous-unwind-tables "

export CC="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-gcc"
export CXX="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-g++"
export CPP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-cpp"

export LD="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-ld"
export NM="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-nm"
export STRIP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-strip"
export AR="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-ar"
export RANLIB="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-ranlib"
export AS="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-as"
export DLLTOOL="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-dlltool"
export OBJDUMP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-objdump"
export DLLWRAP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-dllwrap"

export RESCOMP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-windres"
export WINDRES="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-windres"
export RC="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-windres"

export PKG_CONFIG="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-pkgconf-config"
export PKG_CONFIG_LIBDIR=${DST_DIR}/bin/${WIN32_TARGET_ARCH}/lib/pkgconfig


PATH="${DST_DIR}/bin/:\${PATH}" ../configure \
  --build=${BUILD_ARCH} --host=${WIN32_TARGET_ARCH} --target=${WIN32_TARGET_ARCH} \
  --prefix=${DST_DIR}/${WIN32_TARGET_ARCH} --libdir=${DST_DIR}/${WIN32_TARGET_ARCH}/lib --includedir=${DST_DIR}/${WIN32_TARGET_ARCH}/include \
  --enable-shared --enable-static "\$@"
_EOF_

chmod 777 ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-configure

[ ! -d "${DST_DIR}/share/mingw" ] && { mkdir -pv "${DST_DIR}/share/mingw"; }

cat << _EOF_ > ${DST_DIR}/share/mingw/toolchain-${WIN32_TARGET_ARCH}.cmake
set (CMAKE_SYSTEM_NAME Windows)
set (CMAKE_SYSTEM_PROCESSOR ${WIN32_TARGET_ARCH})

# specify the cross compiler
set (CMAKE_C_COMPILER ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-gcc)
set (CMAKE_CXX_COMPILER ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-g++)
set (CMAKE_RC_COMPILER ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-windres)

# specify flags
set(CMAKE_C_FLAGS " ${CFLAGS} -fPIC -fno-lto ")
set(CMAKE_CXX_FLAGS " ${CFLAGS} -std=c++11 -fPIC -fno-lto  ")
set(CMAKE_EXE_LINKER_FLAGS " -Wl,-O1,--sort-common,--as-needed -Wl,--file-alignment,4096 -Wl,--export-all-symbols -Wl,--enable-auto-import -static-libgcc  -static-libstdc++ -fasynchronous-unwind-tables ")

# where is the target environment
set (CMAKE_FIND_ROOT_PATH ${DST_DIR}/${WIN32_TARGET_ARCH})

# search for programs in the build host directories
set (CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# for libraries and headers in the target directories
set (CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set (CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set (CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# set the resource compiler (RHBZ #652435)
set (CMAKE_RC_COMPILER ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-windres)
set (CMAKE_MC_COMPILER ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-windmc)

# These are needed for compiling lapack (RHBZ #753906)
set (CMAKE_Fortran_COMPILER ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-gfortran)
set (CMAKE_AR:FILEPATH ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-ar)
set (CMAKE_RANLIB:FILEPATH ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-ranlib)
_EOF_

cat << _EOF_ > ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-cmake

export _MINGW_PREFIX_="${DST_DIR}/bin/${WIN32_TARGET_ARCH}"

export CFLAGS="${CFLAGS} -fPIC -fno-lto "
export CXXFLAGS="${CFLAGS} -std=c++11 -fPIC -fno-lto "
export CPPFLAGS="${CFLAGS} -fPIC -fno-lto "
export LDFLAGS=" -Wl,-O1,--sort-common,--as-needed -Wl,--file-alignment,4096 -Wl,--export-all-symbols  -Wl,--enable-auto-import -static-libgcc  -static-libstdc++ -fasynchronous-unwind-tables "

export CC="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-gcc"
export CXX="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-g++"
export CPP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-cpp"

export LD="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-ld"
export NM="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-nm"
export STRIP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-strip"
export AR="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-ar"
export RANLIB="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-ranlib"
export AS="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-as"
export DLLTOOL="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-dlltool"
export OBJDUMP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-objdump"
export DLLWRAP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-dllwrap"

export RESCOMP="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-windres"
export WINDRES="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-windres"
export RC="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-windres"

export PKG_CONFIG="${DST_DIR}/bin/${WIN32_TARGET_ARCH}-pkgconf-config"
export PKG_CONFIG_LIBDIR=$DST_DIR/$WIN32_TARGET_ARCH/lib/pkgconfig

PATH=${DST_DIR}/bin:\$PATH cmake \
    -DCMAKE_INSTALL_PREFIX:PATH=${DST_DIR}/${WIN32_TARGET_ARCH} \
    -DCMAKE_INSTALL_LIBDIR:PATH=lib \
    -DCMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES:PATH=${DST_DIR}/${WIN32_TARGET_ARCH}/include \
    -DCMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES:PATH=${DST_DIR}/${WIN32_TARGET_ARCH}/include \
    -DCMAKE_BUILD_TYPE=None \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DCMAKE_TOOLCHAIN_FILE=${DST_DIR}/share/mingw/toolchain-${WIN32_TARGET_ARCH}.cmake \
    -DCMAKE_CROSSCOMPILING_EMULATOR=${DST_DIR}/bin/${WIN32_TARGET_ARCH}-wine \
    "\$@"
_EOF_

cat << _EOF_ > ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-wine
WINEDEBUG=-all
WINEPREFIX=/tmp/wineprefix-tmp-${WIN32_TARGET_ARCH}
if test "${WIN32_TARGET_ARCH}" = "x86_64-w64-mingw32"
then
  export WINEARCH=win64
else
  export WINEARCH=win32
fi
wine ""\$@""
_EOF_

chmod 777 ${DST_DIR}/share/mingw/toolchain-${WIN32_TARGET_ARCH}.cmake
chmod 777 ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-cmake
chmod 777 ${DST_DIR}/bin/${WIN32_TARGET_ARCH}-wine

}

mkdir -p $DST_DIR

BINUTILS_EXTRA_CONFIGURE=" --enable-libssp --with-static-standard-libraries=yes --enable-host-shared --enable-gold=yes --enable-ld=yes --enable-serial-host-configure --enable-serial-target-configure --enable-serial-build-configure --enable-libada --enable-libssp --enable-plugins --with-system-zlib --enable-relro --enable-threads --with-pic --disable-gdb --enable-targets=i386-efi-pe  --enable-initfini-array " \
GCC_EXTRA_CONFIGURE=" --libexecdir=${DST_DIR}/lib --enable-host-shared --enable-host-pie --enable-serial-host-configure --enable-serial-target-configure --enable-serial-build-configure --with-default-libstdcxx-abi=new --with-diagnostics-color=auto --with-dwarf2 --with-libiconv --without-cuda-driver --enable-languages=c,c++,lto --enable-shared --enable-static --enable-__cxa_atexit --enable-checking=release --enable-cloog-backend=isl --enable-fully-dynamic-string --enable-libgomp --enable-libada --enable-libatomic --enable-graphite --enable-libquadmath --enable-libquadmath-support --enable-libssp --enable-libstdcxx --enable-libstdcxx-time=yes --enable-libstdcxx-visibility --enable-libstdcxx-threads --enable-libstdcxx-filesystem-ts=yes --enable-lto --enable-pie-tools --enable-threads=posix --enable-install-libiberty --disable-libstdcxx-debug --disable-libstdcxx-pch --disable-multilib --disable-nls --disable-sjlj-exceptions --disable-werror  --with-boot-ldflags=-static-libstdc++ --with-stage1-ldflags=-static-libstdc++ --enable-gold=yes --with-as=${DST_DIR}/bin/i686-w64-mingw32-as --with-ar=${DST_DIR}/bin/i686-w64-mingw32-ar --with-ld=${DST_DIR}/bin/i686-w64-mingw32-ld --with-gnu-as=${DST_DIR}/bin/i686-w64-mingw32-as --with-gnu-ld=${DST_DIR}/bin/i686-w64-mingw32-ld --enable-large-address-aware --enable-default-pie --enable-default-ssp --enable-cet --disable-libunwind-exceptions --enable-mingw-wildcard --with-system-zlib --with-fpmath=sse --enable-linker-build-id --disable-vtable-verify --enable-libmudflap --enable-host-bind-now " MINGW_W64_CRT_EXTRA_CONFIGURE="--disable-lib64 --enable-lib32" build_arch x86_64-linux-gnu i686-w64-mingw32

BINUTILS_EXTRA_CONFIGURE=" --enable-libssp --with-static-standard-libraries=yes --enable-host-shared --enable-gold=yes --enable-ld=yes --enable-serial-host-configure --enable-serial-target-configure --enable-serial-build-configure --enable-libada --enable-libssp --enable-plugins --with-system-zlib --enable-relro --enable-threads --with-pic --disable-gdb --enable-64-bit-bfd --enable-targets=x86_64-pep  --enable-initfini-array " \
GCC_EXTRA_CONFIGURE=" --libexecdir=${DST_DIR}/lib --enable-host-shared --enable-host-pie --enable-serial-host-configure --enable-serial-target-configure --enable-serial-build-configure --with-default-libstdcxx-abi=new --with-diagnostics-color=auto --with-libiconv --without-cuda-driver --enable-languages=c,c++,lto --enable-shared --enable-static --enable-__cxa_atexit --enable-checking=release --enable-cloog-backend=isl --enable-fully-dynamic-string --enable-libgomp --enable-libada --enable-libatomic --enable-graphite --enable-libquadmath --enable-libquadmath-support --enable-libssp --enable-libstdcxx --enable-libstdcxx-time=yes --enable-libstdcxx-visibility --enable-libstdcxx-threads --enable-libstdcxx-filesystem-ts=yes --enable-lto --enable-pie-tools --enable-threads=posix --enable-install-libiberty --disable-libstdcxx-debug --disable-libstdcxx-pch --disable-multilib --disable-nls --disable-sjlj-exceptions --with-dwarf2 --disable-werror --with-as=${DST_DIR}/bin/x86_64-w64-mingw32-as --with-ar=${DST_DIR}/bin/x86_64-w64-mingw32-ar --with-ld=${DST_DIR}/bin/x86_64-w64-mingw32-ld --with-gnu-as=${DST_DIR}/bin/x86_64-w64-mingw32-as --with-gnu-ld=${DST_DIR}/bin/x86_64-w64-mingw32-ld --with-boot-ldflags=-static-libstdc++ --with-stage1-ldflags=-static-libstdc++ --enable-gold=yes  --enable-large-address-aware --enable-default-pie --enable-default-ssp --enable-cet --enable-cld --disable-libunwind-exceptions --enable-mingw-wildcard --with-system-zlib --with-fpmath=sse --enable-linker-build-id --disable-vtable-verify --enable-libmudflap --enable-host-bind-now " MINGW_W64_CRT_EXTRA_CONFIGURE="--disable-lib32 --enable-lib64" build_arch x86_64-linux-gnu x86_64-w64-mingw32

echo "Done!"

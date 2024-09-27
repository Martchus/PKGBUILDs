#!/bin/sh

_target=$1
_arch=${_target%%-*}

cross_clang_flags="-rtlib=compiler-rt -fuse-ld=lld -mguard=cf -target $_target -Xclang -triple -Xclang $_target"
default_mingw_pp_flags="-D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS"
default_mingw_compiler_flags="$cross_clang_flags $default_mingw_pp_flags -O2 -pipe -fno-plt -fexceptions --param=ssp-buffer-size=4 -Wformat -Werror=format-security -mguard=cf"
default_mingw_cxx_compiler_flags="$default_mingw_compiler_flags -stdlib=libc++ -isystem/usr/$_target/include/c++/v1 -isystem/usr/$_target/include"
default_mingw_linker_flags="-Wl,-O1,--sort-common,--as-needed -fstack-protector"
[[ $_arch == aarch64 ]] || [[ $_arch =~ arm.* ]] || default_mingw_compiler_flags+=" -fcf-protection"

export CPPFLAGS="${MINGW_CPPFLAGS:-$default_mingw_pp_flags $CPPFLAGS}"
export CFLAGS="${MINGW_CFLAGS:-$default_mingw_compiler_flags $CFLAGS}"
export CXXFLAGS="${MINGW_CXXFLAGS:-$default_mingw_cxx_compiler_flags $CXXFLAGS}"
export ASMFLAGS="${MINGW_ASMFLAGS:-$default_mingw_compiler_flags $ASMFLAGS}"
export LDFLAGS="${MINGW_LDFLAGS:-$default_mingw_linker_flags $LDFLAGS}"

export CC=${MINGW_CC:-clang}
export CXX=${MINGW_CXX:-clang++}
export ASM=${MINGW_CXX:-clang}
export AR=${MINGW_CXX:-llvm-ar}
export LD=${MINGW_CXX:-lld}
export RANLIB=${MINGW_CXX:-llvm-ranlib}
export DLLTOOL=${MINGW_CXX:-llvm-dlltool}

mingw_prefix=/usr/${_target}
export PKG_CONFIG_SYSROOT_DIR="${mingw_prefix}"
export PKG_CONFIG_LIBDIR="${mingw_prefix}/lib/pkgconfig:${mingw_prefix}/share/pkgconfig"

#!/bin/sh

_target=$1
_arch_=${_target%%-*}

[ $USE_COMPILER_WRAPPERS ] && \
  compiler_prefix=mingw- || \
  cross_clang_flags="-rtlib=compiler-rt -fuse-ld=lld -mguard=cf -target $_target -Xclang -triple -Xclang $_target"
default_mingw_pp_flags="-D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS"
default_mingw_compiler_flags="$cross_clang_flags $default_mingw_pp_flags -O2 -pipe -fexceptions --param=ssp-buffer-size=4 -Wformat -Werror=format-security -mguard=cf"
default_mingw_cxx_compiler_flags="$default_mingw_compiler_flags -stdlib=libc++ -isystem/usr/$_target/include/c++/v1 -isystem/usr/$_target/include"
default_mingw_linker_flags="$cross_clang_flags -Wl,-O1,--sort-common,--as-needed -fstack-protector"
[[ $_arch_ == aarch64 ]] || [[ $_arch_ =~ arm.* ]] || default_mingw_compiler_flags+=" -fcf-protection"

export MINGW_W64_CLANG_TARGET=$_target
export CPPFLAGS="${MINGW_CPPFLAGS:-$default_mingw_pp_flags $CPPFLAGS}"
export CFLAGS="${MINGW_CFLAGS:-$default_mingw_compiler_flags $CFLAGS}"
export CXXFLAGS="${MINGW_CXXFLAGS:-$default_mingw_cxx_compiler_flags $CXXFLAGS}"
export ASMFLAGS="${MINGW_ASMFLAGS:-$default_mingw_compiler_flags $ASMFLAGS}"
export LDFLAGS="${MINGW_LDFLAGS:-$default_mingw_linker_flags $LDFLAGS}"

export CC=${MINGW_CC:-${compiler_prefix}clang}
export CXX=${MINGW_CXX:-${compiler_prefix}clang++}
export ASM=${MINGW_ASM:-${compiler_prefix}clang}
export AR=${MINGW_AR:-llvm-ar}
export NM=${MINGW_NM:-llvm-nm}
export LD=${MINGW_LD:-mingw-lld}
export STRIP=${MINGW_STRIP:-mingw-llvm-strip}
export RANLIB=${MINGW_RANLIB:-llvm-ranlib}
export DLLTOOL=${MINGW_DLLTOOL:-llvm-dlltool}
export WINDRES=${MINGW_WINDRES:-mingw-llvm-windres}
export RC=${MINGW_RC:-mingw-llvm-windres}

mingw_prefix=/usr/${_target}
export PKG_CONFIG_SYSROOT_DIR="${mingw_prefix}"
export PKG_CONFIG_LIBDIR="${mingw_prefix}/lib/pkgconfig:${mingw_prefix}/share/pkgconfig"

#!/bin/bash
_target=$1
_arch_=${_target%%-*}

# add arch-specific flags in consistency with MSYS2-packages
# https://github.com/msys2/MSYS2-packages: pacman/makepkg_mingw.d.clangarm64.conf, pacman/makepkg_mingw.d.clang64.conf
arch_flags=()
[[ $_arch_ == aarch64 ]] && arch_flags="-march=armv8.1-a"
[[ $_arch_ == x86_64 ]] && arch_flags="-march=nocona -msahf -mtune=generic"

# configure clang flags to enable cross compilation or use compiler wrappers
[[ $USE_COMPILER_WRAPPERS ]] && \
  compiler_prefix=mingw- || \
  cross_clang_flags="-rtlib=compiler-rt -fuse-ld=lld -target $_target -Xclang -triple -Xclang $_target"

# configure further flags using flags from regular Arch as far as it makes sense
# omit `-Wp,-D_FORTIFY_SOURCE=2` for now as it causes Qt 6 apps to hang, see f7c5947c2c92f516701d40373c98af3556edf8f6
default_mingw_pp_flags=""
# add `-fstack-protector-strong` as MSYS2 uses it
# omit `--param=ssp-buffer-size=4` as not present in MSYS2
default_mingw_compiler_flags="$cross_clang_flags $default_mingw_pp_flags $arch_flags -O2 -pipe -fexceptions -Wformat -Werror=format-security -fstack-protector-strong"
default_mingw_cxx_compiler_flags="$default_mingw_compiler_flags -stdlib=libc++ -isystem/usr/$_target/include/c++/v1 -isystem/usr/$_target/include"
# omit `-Wl,-O1,--sort-common,--as-needed -fstack-protector` as not present in MSYS2
default_mingw_linker_flags="$cross_clang_flags"

# do NOT enable `-mguard=cf` and `-fcf-protection` by default in consistency with MSYS2 packages
[[ $USE_FC_PROTECTION ]] && [[ $_arch_ != aarch64 ]] && [[ ! $_arch_ =~ arm.* ]] && default_mingw_compiler_flags+=" -fcf-protection"
[[ $USE_MGUARD ]] && default_mingw_compiler_flags+=" -mguard=cf"

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

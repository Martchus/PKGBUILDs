#!/bin/sh
mingw_prefix=/usr/@TRIPLE@

export PKG_CONFIG_LIBDIR="${mingw_prefix}/lib/pkgconfig"

default_mingw_pp_flags="-D_FORTIFY_SOURCE=2"
default_mingw_compiler_flags="$default_mingw_pp_flags -O2 -pipe -fno-plt -fexceptions --param=ssp-buffer-size=4"
default_mingw_linker_flags="-Wl,-O1,--sort-common,--as-needed"

export CPPFLAGS="${MINGW_CPPFLAGS:-$default_mingw_pp_flags $CPPFLAGS}"
export CFLAGS="${MINGW_CFLAGS:-$default_mingw_compiler_flags $CFLAGS}"
export CXXFLAGS="${MINGW_CXXFLAGS:-$default_mingw_compiler_flags $CXXFLAGS}"
export LDFLAGS="${MINGW_LDFLAGS:-$default_mingw_linker_flags $LDFLAGS}"

# allow overriding certain defaults
extra_args=()
declare -A variables_to_preserve=(
    [CMAKE_BUILD_TYPE]=Release
    [BUILD_SHARED_LIBS]=ON
)
variable_to_preserve_regex='-D(CMAKE_BUILD_TYPE|BUILD_SHARED_LIBS)(:.*)=(.*)'
for arg in "$@"; do
    if [[ $arg =~ $variable_to_preserve_regex ]]; then
        variables_to_preserve[${BASH_REMATCH[1]}]=${BASH_REMATCH[3]}
    else
        extra_args+=("$arg")
    fi
done

PATH=${mingw_prefix}/bin:$PATH cmake \
    -DCMAKE_INSTALL_PREFIX:PATH=${mingw_prefix} \
    -DCMAKE_INSTALL_LIBDIR:PATH=${mingw_prefix}/lib \
    -DINCLUDE_INSTALL_DIR:PATH=${mingw_prefix}/include \
    -DLIB_INSTALL_DIR:PATH=${mingw_prefix}/lib \
    -DSYSCONF_INSTALL_DIR:PATH=${mingw_prefix}/etc \
    -DSHARE_INSTALL_DIR:PATH=${mingw_prefix}/share \
    -DCMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES:PATH=${mingw_prefix}/include \
    -DCMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES:PATH=${mingw_prefix}/include \
    -DBUILD_SHARED_LIBS:BOOL="${variables_to_preserve[BUILD_SHARED_LIBS]}" \
    -DCMAKE_TOOLCHAIN_FILE=/usr/share/mingw/toolchain-@TRIPLE@.cmake \
    -DCMAKE_CROSSCOMPILING_EMULATOR=/usr/bin/@TRIPLE@-wine \
    -DCMAKE_BUILD_TYPE="${variables_to_preserve[CMAKE_BUILD_TYPE]}" \
    -DCMAKE_C_FLAGS_RELEASE="$CFLAGS" \
    -DCMAKE_CXX_FLAGS_RELEASE="$CXXFLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS_RELEASE="$LDFLAGS" \
    -DCMAKE_EXE_LINKER_FLAGS_RELEASE="$LDFLAGS" \
    "${extra_args[@]}"

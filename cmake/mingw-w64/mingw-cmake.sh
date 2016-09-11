#!/bin/sh
mingw_prefix=/usr/@TRIPLE@

export PKG_CONFIG_LIBDIR="${mingw_prefix}/lib/pkgconfig"

mingw_flags="${CUSTOM_MINGW_FLAGS:--O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions --param=ssp-buffer-size=4}"
export CFLAGS="$mingw_flags $CFLAGS"
export CXXFLAGS="$mingw_flags $CXXFLAGS"

additional_args=" \
  -DCMAKE_INSTALL_PREFIX:PATH=${mingw_prefix} \
  -DCMAKE_INSTALL_LIBDIR:PATH=${mingw_prefix}/lib \
  -DINCLUDE_INSTALL_DIR:PATH=${mingw_prefix}/include \
  -DCMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES:PATH=${mingw_prefix}/include \
  -DCMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES:PATH=${mingw_prefix}/include \
  -DLIB_INSTALL_DIR:PATH=${mingw_prefix}/lib \
  -DSYSCONF_INSTALL_DIR:PATH=${mingw_prefix}/etc \
  -DSHARE_INSTALL_DIR:PATH=${mingw_prefix}/share \
  -DCMAKE_TOOLCHAIN_FILE=/usr/share/mingw/toolchain-@TRIPLE@.cmake \
  -DCMAKE_CROSSCOMPILING_EMULATOR=/usr/bin/@TRIPLE@-wine"

[[ ! $PREVENT_FORCING_SHARED_LIBS ]] &&
  additional_args+=' -DBUILD_SHARED_LIBS:BOOL=ON' ||
  additional_args+=' -DBUILD_SHARED_LIBS:BOOL=OFF'

PATH=${mingw_prefix}/bin:$PATH cmake $additional_args "$@"

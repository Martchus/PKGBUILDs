#!/bin/sh
arm_prefix=/usr/@TRIPLE@
export PKG_CONFIG_LIBDIR="${arm_prefix}/lib/pkgconfig"

arm_flags="${CUSTOM_MINGW_FLAGS:--O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions --specs=nosys.specs}"
export CFLAGS="$arm_flags $CFLAGS"
export CXXFLAGS="$arm_flags $CXXFLAGS"

additional_args=" \
  -DCMAKE_INSTALL_PREFIX:PATH=${arm_prefix} \
  -DCMAKE_INSTALL_LIBDIR:PATH=${arm_prefix}/lib \
  -DINCLUDE_INSTALL_DIR:PATH=${arm_prefix}/include \
  -DCMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES:PATH=${arm_prefix}/include \
  -DCMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES:PATH=${arm_prefix}/include \
  -DLIB_INSTALL_DIR:PATH=${arm_prefix}/lib \
  -DSYSCONF_INSTALL_DIR:PATH=${arm_prefix}/etc \
  -DSHARE_INSTALL_DIR:PATH=${arm_prefix}/share \
  -DCMAKE_TOOLCHAIN_FILE=/usr/share/@TRIPLE@/toolchain-@TRIPLE@.cmake"

cmake $additional_args "$@"

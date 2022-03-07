#!/bin/sh

static_compat_prefix=/usr/static-compat
export PATH=$static_compat_prefix/bin:$PATH
export CC=$static_compat_prefix/bin/gcc
export CXX=$static_compat_prefix/bin/g++
export CFLAGS="$CFLAGS -fPIC"
export CXXFLAGS="$CXXFLAGS -fPIC"
export CPPFLAGS="$CPPFLAGS"
export PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-$static_compat_prefix/usr/lib/pkgconfig:$static_compat_prefix/usr/share/pkgconfig}
export PKG_CONFIG_SYSROOT_DIR=${PKG_CONFIG_SYSROOT_DIR:-$static_compat_prefix}
export PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR:-$static_compat_prefix/lib/pkgconfig:$static_compat_prefix/share/pkgconfig}

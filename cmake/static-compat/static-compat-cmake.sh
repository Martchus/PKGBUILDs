#!/bin/sh

source static-compat-environment

cmake \
    -DCMAKE_INSTALL_PREFIX:PATH="$static_compat_prefix" \
    -DCMAKE_INSTALL_LIBDIR:PATH=lib \
    -DCMAKE_FIND_ROOT_PATH:PATH="$static_compat_prefix" \
    -DCMAKE_C_COMPILER:PATH="$static_compat_prefix/bin/gcc" \
    -DCMAKE_CXX_COMPILER:PATH="$static_compat_prefix/bin/g++" \
    -DCMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES:PATH="$static_compat_prefix"/include \
    -DCMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES:PATH="$static_compat_prefix"/include \
    -DBUILD_SHARED_LIBS:BOOL=OFF \
    "$@"

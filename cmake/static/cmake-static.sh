#!/bin/sh

static_prefix=/usr/static

PATH=${static_prefix}/bin:$PATH cmake \
    -DCMAKE_INSTALL_PREFIX:PATH="${static_prefix}" \
    -DCMAKE_INSTALL_LIBDIR:PATH=lib \
    -DBUILD_SHARED_LIBS:BOOL=OFF \
    -DCMAKE_TOOLCHAIN_FILE=/usr/share/static/toolchain/toolchain-static.cmake \
    "$@"

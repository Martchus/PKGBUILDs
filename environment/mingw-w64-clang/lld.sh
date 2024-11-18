#!/bin/sh

# pass the machine argument and special platform library flags for build systems that invoke the linker directly
target=${MINGW_W64_CLANG_TARGET:-aarch64-w64-mingw32}
arch="${target%%-*}"
os="${target##*-}"
case $arch in
i686) machine=i386pe  ;;
x86_64) machine=i386pep ;;
armv7) machine=thumb2pe ;;
aarch64) machine=arm64pe ;;
esac
FLAGS="-m $machine"
case $os in
mingw32uwp)
    FLAGS+=" -lwindowsapp -lucrtapp"
    ;;
esac
ld.lld $FLAGS "$@"

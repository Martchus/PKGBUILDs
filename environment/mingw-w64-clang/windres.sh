#!/bin/sh

# pass architecture
_target=${MINGW_W64_CLANG_TARGET:-aarch64-w64-mingw32}
llvm-windres -F "$_target" "$@"

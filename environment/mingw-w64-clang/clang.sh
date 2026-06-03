#!/bin/bash

# pass important flags via this wrapper for build systems that don't use CFLAGS consistently
_target=${MINGW_W64_CLANG_TARGET:-aarch64-w64-mingw32}
[[ $NO_MGUARD ]] && _mguard= || _mguard=-mguard=cf
clang -rtlib=compiler-rt -fuse-ld=lld $_mguard -target $_target -Xclang -triple -Xclang $_target "$@"

#!/bin/bash

# pass important flags via this wrapper for build systems that don't use CXXFLAGS consistently
_target_from_name=${0%-clang*}
_target_from_name=${_name##*/}
_target=${MINGW_W64_CLANG_TARGET:-${_name:-aarch64-w64-mingw32}}
clang++ -stdlib=libc++ -rtlib=compiler-rt -fuse-ld=lld -target $_target_from_name -Xclang -triple -Xclang $_target "$@"

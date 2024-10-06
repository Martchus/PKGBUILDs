#!/bin/sh

# pass important flags via this wrapper for build systems that don't use CXXFLAGS consistently
_target=${TARGET:-aarch64-w64-mingw32}
clang++ -rtlib=compiler-rt -fuse-ld=lld -mguard=cf -target $_target -Xclang -triple -Xclang $_target "$@"

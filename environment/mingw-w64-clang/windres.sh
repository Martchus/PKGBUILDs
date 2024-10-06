#!/bin/sh

# pass architecture
_target=${TARGET:-aarch64-w64-mingw32}
llvm-windres -F "$_target" "$@"

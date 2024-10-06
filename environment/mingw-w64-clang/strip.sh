#!/bin/bash

args=()
for arg in "$@"; do
    # filter out import libraries because llvm-strip returns "unsupported object file format" for those
    [[ $arg == *.dll.a ]] || args+=("$arg")
done
llvm-strip "${args[@]}"

#!/bin/bash

args=()
file_count=0
for arg in "$@"; do
    # filter out import libraries because llvm-strip returns "unsupported object file format" for those
    [[ $arg == *.dll.a ]] && continue
    [[ $arg != -* ]] && file_count=$((file_count + 1))
    args+=("$arg")
done
if [[ $file_count -gt 0 ]]; then
    llvm-strip "${args[@]}"
fi

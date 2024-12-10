#!/bin/bash
pacparse=($(which pacparse-git pacparse))
set -e # abort on first error
shopt -s nullglob
shopt -s extglob
source "$(dirname $0)/../versions.sh"

if [[ $EXPERIMENTAL ]]; then
    repo_dir=${PATH_REPO_OWNSTUFF_EXPERIMENTAL}
else
    repo_dir=${PATH_REPO_OWNSTUFF}
fi
if ! [[ $repo_dir ]]; then
    echo "\$PATH_REPO_OWNSTUFF is empty."
    exit -1
fi
repo_dir+='/x86_64'
if ! [[ -d $repo_dir ]]; then
    echo "\$PATH_REPO_OWNSTUFF/x86_64 does not point to a directory."
    exit -1
fi

crtlibs_path=/tmp/crtlibs.txt
if [[ -f $crtlibs_path ]]; then
    echo "Using existing crt library list from $crtlibs_path"
else
    crt_x86=("$repo_dir"/mingw-w64-crt-*.pkg.tar.zst)
    crt_aarch64=("$repo_dir"/mingw-w64-clang-aarch64-crt-*.pkg.tar.zst)
    crt=("${crt_x86[-1]}" "${crt_aarch64[-1]}")
    echo "Reading libraries from the following crt packages: ${crt[@]}"
    "${pacparse[0]}" --packages "${crt[@]}" | jq -r '.packages[] | .libprovides[]' > "$crtlibs_path"
fi

required_libs=($("${pacparse[0]}" --binaries "$@" | jq -r '.binaries[] | ("pe-" + .architecture + "::" + .requiredLibs[])'))

found=() missing=()
for lib in "${required_libs[@]}"; do
    if [[ $lib =~ api-ms-win-.* ]]; then
        found+=("$lib")
    else
        grep --quiet -i "^$lib\$" "$crtlibs_path" && found+=("$lib") || missing+=("$lib")
    fi
done

echo "found: ${found[@]}"
echo "missing: ${missing[@]}"
[[ ${#missing[@]} == 0 ]] && exit 0 || exit 1

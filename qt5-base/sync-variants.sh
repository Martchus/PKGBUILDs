#!/usr/bin/bash

# Syncs the different variants of mingw-w64-qt5-base

set -e # abort on first error
master="${1:-mingw-w64}"

[[ -d 'qt5-base' ]] && pushd 'qt5-base' || pushd .

if [ $# -gt 1 ]; then
  echo "Error: too many arguments specified"
  echo "Usage: $0 master_dir"
  exit -2
elif [[ ! -d $master ]]; then
  echo "Error: specified master $master does not exist"
  exit -3
fi

for dir in mingw-w64 mingw-w64-*; do
  [[ $dir == *'-test' ]] && continue
  if [[ $dir != $master ]] && [[ -d $dir ]]; then
    rm "$dir/"* # clean first (files might have been removed in master)
    cp "$master/"* "$dir"
    sed -e '/pkgname=mingw-w64-qt5-base/{c\pkgname=mingw-w64-qt5-base'${dir#mingw-w64} -e ';d}' "$master/PKGBUILD" > "$dir/PKGBUILD"
  fi
done

popd

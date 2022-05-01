#!/bin/bash

# Syncs the different variants of mingw-w64-qt5-base

set -e # abort on first error
shopt -s extglob
master="${1:-mingw-w64}"

if [ $# -gt 1 ]; then
  echo "Error: too many arguments specified"
  echo "Usage: $0 master_dir"
  exit -2
elif [[ ! -d $master ]]; then
  echo "Error: specified master $master does not exist"
  exit -3
fi

for dir in *; do
  if [[ $dir != $master ]] && [[ -d $dir ]] && [[ $dir =~ mingw-w64-.* ]]; then
    rm "$dir/"* # clean first (files might have been remove in master)
    cp "$master/"PKGBUILD "$dir"
    ln -rs "$master/"!(PKGBUILD) "$dir"
    sed -e '/pkgname=mingw-w64-freetype2/{c\pkgname=mingw-w64-freetype2'${dir#mingw-w64} -e ';d}' "$master/PKGBUILD" > "$dir/PKGBUILD"
  fi
done

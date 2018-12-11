#!/bin/bash

# Syncs the different variants of android-openssl

set -e # abort on first error
master="${1:-android-aarch64}"

[[ -d 'openssl' ]] && pushd 'openssl' || pushd .

if [ $# -gt 1 ]; then
  echo "Error: too many arguments specified"
  echo "Usage: $0 master_dir"
  exit -2
elif [[ ! -d $master ]]; then
  echo "Error: specified master $master does not exist"
  exit -3
fi

for dir in android-*; do
  [[ $dir == *'-test' ]] && continue
  [[ $dir == $master ]]  && continue
  [[ -d $dir ]]          || continue

  source "$dir/PKGBUILD"
  rm "$dir/"* # clean first (files might have been removed in master)
  cp "$master/"* "$dir"
  sed -e "s/pkgname=android-.*-openssl/pkgname=$dir-openssl/" \
      -e "s/_android_arch=.*/_android_arch=$_android_arch/" \
      -e "s/_pkg_arch=.*/_pkg_arch=$_pkg_arch/" \
      -e "s/_android_platform=.*/_android_platform=$_android_platform/" \
      "$master/PKGBUILD" > "$dir/PKGBUILD"
done

popd

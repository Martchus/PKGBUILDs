#!/bin/bash

# Syncs the different variants of android-openssl

set -e # abort on first error
master="${1:-android-arm64-v8a}"

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
  sed -e "s/pkgname=android-openssl-.*/pkgname=android-openssl${dir#android}/" \
      -e "s/ANDROID_EABI=.*/ANDROID_EABI=$ANDROID_EABI/" \
      -e "s/ANDROID_ARCH=.*/ANDROID_ARCH=$ANDROID_ARCH/" \
      -e "s/_android_arch=.*/_android_arch=$_android_arch/" \
      "$master/PKGBUILD" > "$dir/PKGBUILD"
done

popd

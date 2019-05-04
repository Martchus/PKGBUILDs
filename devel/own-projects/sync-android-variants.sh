#!/usr/bin/bash -e
basedir=$(dirname "$0")/../..
for project in c++utilities qtutilities passwordfile tagparser passwordmanager; do
    pushd "$basedir/$project" > /dev/null
    ../devel/sync-variants.sh . android-aarch64 android-*
    popd > /dev/null
done

#!/usr/bin/bash -e
cd "$(dirname "$0")/../${1:-qt5}"
../devel/sync-variants.sh . android-aarch64 android-*

#!/usr/bin/bash

# setup shell environment
set -e # abort on first error
shopt -s nullglob
shopt -s extglob
export BASHOPTS
source /usr/share/devtools/lib/util/pkgbuild.sh
source /usr/share/makepkg/util/message.sh
[[ $ALL_OFF ]] || colorize

for pkg_dir in "$@"; do
    if [[ -f $pkg_dir/default/PKGBUILD ]]; then
        pkg_dir+=/default
    fi
    if [[ ! -f $pkg_dir/PKGBUILD ]]; then
        msg "$pkg_dir/PKGBUILD does not exist"
        continue
    fi
    pushd "$pkg_dir" > /dev/null
    pkgname= pkgver= pkgrel=
    source ./PKGBUILD
    oldpkgrel=$pkgrel
    newpkgrel=$((oldpkgrel + 1))
    msg "Updating $pkgname: $pkgver-$oldpkgrel -> $pkgver-$newpkgrel"
    pkgbuild_set_pkgrel "$((pkgrel + 1))"
    if [[ $COMMIT ]] || [[ $COMMIT_MESSAGE ]]; then
        git add ./PKGBUILD
        git commit -m "${COMMIT_MESSAGE:-Rebuild $pkgname}"
    fi
    popd > /dev/null
done

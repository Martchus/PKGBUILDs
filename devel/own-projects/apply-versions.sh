#!/bin/bash
set -e # abort on first error
shopt -s nullglob
source versions.sh

for pkgbuild_file in "${PKGBUILD_DIR:-../..}"/*/*/PKGBUILD; do
    trimmed_path=${pkgbuild_file#${PKGBUILD_DIR:-../..}/}
    project_name=${trimmed_path%%/*}
    variant=${trimmed_path%/PKGBUILD}
    variant=${variant#$project_name/}

    # skip Git packages
    [ ${variant##*-} == 'git' ] && continue

    # skip some of the qt5 packages
    [[ $project_name == 'qt5-quick1' || $project_name == 'qt5-webkit' || $project_name == 'qt5-webview' || $variant == 'mingw-w64-test' ]] && continue

    # treat all qt5-* packages as qt5
    [ ${project_name%%-*} == 'qt5' ] && project_name='qt5'

    # skip packages with unknown version
    version=${versions[$project_name]}
    [[ $version ]] || continue

    # skip if version doesn't differ
    source "$pkgbuild_file"
    [[ $version == $pkgver ]] && continue

    # apply new version
    sed -i -e "s/pkgver=.*/pkgver=$version/" -e "s/pkgrel=.*/pkgrel=1/" "$pkgbuild_file"
    chmod 644 "$pkgbuild_file"

    echo "$trimmed_path -> $version"
done

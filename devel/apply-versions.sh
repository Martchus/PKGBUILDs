#!/bin/bash
set -e # abort on first error
shopt -s nullglob
source "$(dirname $0)/versions.sh"

for pkgbuild_file in "${PKGBUILD_DIR:-.}"/*/*/PKGBUILD; do
    trimmed_path=${pkgbuild_file#${PKGBUILD_DIR:-.}/}
    project_name=${trimmed_path%%/*}
    variant=${trimmed_path%/PKGBUILD}
    variant=${variant#$project_name/}

    # skip Git packages
    [ ${variant##*-} == 'git' ] && continue

    # skip some of the qt5 packages
    [[    $project_name == 'qt5-quick1'         # removed from official releases
       || $project_name == 'qt5-webkit'         # even revived version is dead
       || $project_name == 'qt5-webview'        # does not build for Windows, would require qt5-webengine
       || $project_name == 'qt5-canvas3d'       # removed from official releases
       || $variant      == 'mingw-w64-test'     # just our own 'test' package (not used anymore)
    ]] && continue

    # treat all qt5-* packages as qt5
    [ ${project_name%%-*} == 'qt5' ] && project_name='qt5'

    # skip packages with unknown version
    version=${versions[$project_name]}
    [[ $version ]] || continue

    # skip if version doesn't differ
    source "$pkgbuild_file"
    [[ $version == $pkgver ]] && continue
    pattern='(android|apple-darwin)-.*'
    [[ $pkgname =~ $pattern ]] && continue

    # check if template exists and modify template instead
    template=$pkgbuild_file.sh.ep
    [[ -f $template ]] && pkgbuild_file=$template

    # apply new version
    sed -i -e "s/^pkgver=.*/pkgver=$version/" -e "s/pkgrel=.*/pkgrel=1/" "$pkgbuild_file"
    chmod 644 "$pkgbuild_file"

    echo "$trimmed_path -> $version"
done

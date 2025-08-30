#!/bin/bash
set -e # abort on first error
shopt -s nullglob
bindir=$(dirname "$0")
source "$bindir/versions.sh"

for pkgbuild_file in "${PKGBUILD_DIR:-.}"/*/*/PKGBUILD; do
    trimmed_path=${pkgbuild_file#${PKGBUILD_DIR:-.}/}
    project_name=${trimmed_path%%/*}
    variant=${trimmed_path%/PKGBUILD}
    variant=${variant#$project_name/}

    # skip Git packages
    [ ${variant##*-} == 'git' ] && continue

    # skip android packages (for now)
    [[ $project_name =~ qt5-.* ]] && is_qt5=1 || is_qt5=
    [[ $project_name =~ qt6-.* ]] && is_qt6=1 || is_qt6=
    [ "${variant%%-*}" == 'android' ] && [[ $is_qt5 ]] && continue

    # skip some of the packages
    [[    $project_name == 'qt5-quick1'         # removed from official releases
       || $project_name == 'qt5-webkit'         # even revived version is dead
       || $project_name == 'qt5-webview'        # does not build for Windows, would require qt5-webengine
       || $project_name == 'qt5-canvas3d'       # removed from official releases
       || $project_name == 'qt5-script'         # extra case (still released, not on KDE branch)
       || $variant      == 'mingw-w64-test'     # just our own 'test' package (not used anymore)
    ]] && continue

    # skip default qt6 packages (provided by Arch Linux itself)
    [[ $is_qt6 ]] && [[ $variant == 'default' ]] && continue

    # treat all qt5-*/qt6-* packages as qt5/qt6
    start=${project_name%%-*}
    for qtver in 5 6; do
        [[ $start  == "qt$qtver" ]] && project_name="qt$qtver" && break
    done

    # skip packages with unknown version
    version=${versions[$project_name]}
    [[ $version ]] || continue

    # skip if version doesn't differ
    source "$pkgbuild_file"
    [[ $version == $pkgver ]] && continue
    [[ $version == $_qtver ]] && continue
    pattern='(apple-darwin-.*|android-.*-(c\+\+utilities|qtutilities|passwordfile))'
    [[ $pkgname =~ $pattern ]] && continue

    # check if template exists and modify template instead
    template=$pkgbuild_file.sh.ep
    layoutname=$pkgname
    [[ $layoutname =~ android-aarch64-.* ]] && layoutname=android-${pkgname##android-aarch64-}
    layout=$bindir/generator/templates/layouts/$layoutname.sh.ep
    if [[ -f $layout ]]; then
        [[ $VERBOSE ]] && echo "Considering layout $pkgname.sh.ep for $trimmed_path"
        pkgbuild_file=$layout
    elif [[ -f $template ]]; then
        [[ $VERBOSE ]] && echo "Considering template $trimmed_path.sh.ep for $trimmed_path"
        pkgbuild_file=$template
    fi

    # apply new version
    sed -i -e "s/^\(_qtver\|pkgver\)=[^\$][^<%]*/\1=$version/" -e "s/pkgrel=.*/pkgrel=1/" "$pkgbuild_file"
    chmod 644 "$pkgbuild_file"

    echo "$trimmed_path -> $version"
done

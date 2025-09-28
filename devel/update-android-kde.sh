#!/bin/bash

# updates Android variants of KDE PKGBUILDs using the versions from the regular PKGBUILDs
# TODO: extend/generalize to cover other types of PKGBUILDs as well

set -e
source /usr/share/devtools/lib/util/pkgbuild.sh

arch_pkg_dir=${ARCH_PKG_DIR:-/run/media/devel/src/arch-packages}
pkgs=(
    kcolorscheme
    kconfig
    kcoreaddons
    kguiaddons
    ki18n
    kirigami
    kquickcharts
    qqc2-breeze-style
)

for pkg in "${pkgs[@]}"; do
    msg2 "pkg: $pkg"
    android_pkg=$pkg/android-aarch64
    official_pkg=$arch_pkg_dir/$pkg
    if [[ -z $SKIP_UPDATE ]]; then
        if [[ ! -e $official_pkg ]]; then
            git -C "$arch_pkg_dir" clone "git@gitlab.archlinux.org:archlinux/packaging/packages/$pkg.git"
        else
            git -C "$arch_pkg_dir/$pkg" pull --rebase origin main
        fi
    fi
    source "$official_pkg/PKGBUILD"
    new_pkgver=$pkgver nvchecker_cfg=
    if [[ $ADD_NVCHECKER_CONFIG_FROM_OFFICIAL_PKG ]]; then
        nvchecker_cfg=$official_pkg/.nvchecker.toml
        if [[ ! -e $nvchecker_cfg ]]; then
            echo "no nvchecker config"
            break
        fi
    fi
    pushd "$android_pkg"
    if [[ $nvchecker_cfg ]]; then
        cp -v "$nvchecker_cfg" .nvchecker.toml
        nvchecker -c .nvchecker.toml
        # FIXME: use output from nvchecker
    fi
    source PKGBUILD
    pkgbuild_set_pkgver "$new_pkgver"
    pkgbuild_set_pkgrel "1"
    if [[ -z $SKIP_UPDATE_CHECKSUMS ]]; then
        pkgbuild_update_checksums /dev/stderr
    fi
    popd
    devel/sync-android-variants.sh "$pkg"
    git add "$pkg"/*/PKGBUILD
done

for pkg in "${pkgs[@]}"; do
    for arch in aarch64 armv7a-eabi x86-64 x86; do
        pkg_name=android-$arch-$pkg
        if pacman -Ss "$pkg_name"; then
            pkg_names+=("$pkg_name")
        fi
    done
done

echo "packages to rebuild:"
echo "${pkg_names[@]}"

#!/bin/bash
set -e # abort on first error
shopt -s nullglob
bindir=$(dirname "$0")
source "$bindir/../versions.sh"
expected_version=${versions[qt5]}.*
echo "expected version: $expected_version"

# determine relevant repositories
pushd "$bindir/../.."
repos=()
for pkgbuild in qt5-*/mingw-w64/PKGBUILD ; do
    repos+=("${pkgbuild%/mingw-w64/PKGBUILD}")
done
popd

# change into the specified directory containing Arch PKGBUILD repos 
arch_pkgbuilds=$1
[[ $arch_pkgbuilds ]] && cd "$arch_pkgbuilds"


# ensure all relevant repos are cloned
for repo in "${repos[@]}"; do
    [[ -d $repo ]] ||[[ $repo == qt5-activeqt ]] || [[ $repo == qt5-winextras ]] ||  [[ $repo == qt5-canvas3d ]] || pkgctl repo clone "$repo"
done

# ensure all relevant repos are up-to-date
for pkgbuild in qt5-*/PKGBUILD ; do
    git -C "${pkgbuild%/PKGBUILD}" pull --rebase origin main
done

for pkgbuild in qt5-*/PKGBUILD ; do
    source "$pkgbuild"
    if [[ $pkgname != qt5-doc ]] && [[ $pkgver =~ $expected_version ]] && [[ $_commit ]]; then
        if [[ $pkgver == "${versions[qt5]}" ]]; then
            pkgver=0
        fi
        echo "${pkgname##qt5-} => [${pkgver##*+r}, '$_commit']",
    fi
done


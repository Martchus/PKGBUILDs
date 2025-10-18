#!/bin/bash
set -e

package=$1
variant=$2
official_packages=${OFFICIAL_PACKAGES:-/run/media/devel/src/arch-packages}

current_variant_file=$package/$variant/PKGBUILD
source "$current_variant_file"
variantver=$pkgver
echo "variant version: $variantver"

regular_dir=$official_packages/$package
if [[ ! -e $regular_dir ]]; then
    pushd "$official_packages"
    pkgctl repo clone "$package"
    popd
else
    git -C "$regular_dir" pull --rebase origin main
fi

regular_file=$regular_dir/PKGBUILD
source "$regular_file"
regularver=$pkgver
echo "regular version: $regularver"

if [[ $variantver == "$regularver" ]]; then
    echo "nothing to do, versions are the same"
    exit 0
fi

commits=($(git -C "$regular_dir" log -n 20 --pretty=format:%H HEAD~1 "PKGBUILD"))
tempfile=/tmp/regular-pkgbuild
basecomit=
for commit in "${commits[@]}"; do
    echo "checking diff as of commit $commit"
    git -C "$regular_dir" show "$commit:PKGBUILD" > "$tempfile"
    source "$tempfile"
    if [[ $variantver != "$pkgver" ]]; then
        continue
    fi
    echo "commit $commit is last commit of regular package with version $pkgver"
    basecomit=$commit
    break
done

if [[ ! $basecomit ]]; then
    echo "unable to find commit of regular package with variant version"
    exit 1
fi

cd "$package/$variant"
git -C "$regular_dir" diff "$basecomit..origin/main" -- "PKGBUILD" > regular.diff
if patch -p1 --forward -i regular.diff; then
    echo "patch applied cleanly"
    exit 0
fi

source /usr/share/devtools/lib/util/pkgbuild.sh
source PKGBUILD
[[ $pkgver == "$regularver" ]] && exit 1
echo "trying to set version manually as patch didn't apply"
pkgbuild_set_pkgver "$regularver"
pkgbuild_set_pkgrel "1"
echo "updated pkgver from $pkgver to $regularver manually"
echo "check $regular_dir/PKGBUILD and $PWD/regular.diff for applying other changes manually"

#!/bin/bash
set -e

package=$1
variant=$2
official_packages=${OFFICIAL_PACKAGES:-/run/media/devel/src/svntogit-packages}

current_variant_file=$package/$variant/PKGBUILD
source "$current_variant_file"
variantver=$pkgver
echo "variant version: $variantver"

regular_file=$official_packages/$package/trunk/PKGBUILD
source "$regular_file"
regularver=$pkgver
echo "variant version: $regularver"

if [[ $variantver == "$regularver" ]]; then
    echo "nothing to do, versions are the same"
    exit 0
fi

commits=($(git -C "$official_packages" log -n 8 --pretty=format:%H HEAD~1 "$package/trunk/PKGBUILD"))
tempfile=/tmp/regular-pkgbuild
basecomit=
for commit in "${commits[@]}"; do
    echo "checking diff as of commit $commit"
    git -C "$official_packages" show "$commit:$package/trunk/PKGBUILD" > "$tempfile"
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
git -C "$official_packages" diff "$basecomit..master" -- "$package/trunk/PKGBUILD" > regular.diff
patch -p3 -i regular.diff

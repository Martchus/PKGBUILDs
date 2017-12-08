#!/usr/bin/bash

# Copies patches from QT_GIT_REPOS_DIR to default
# variant of specified repo and updates sources and checksums

#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob

if ! [[ $1 ]]; then
    echo 'No Qt repo specified - must be specified like eg. base or multimedia.'
    echo "Usage: $0 repo [variant=mingw-w64]"
    exit -1
fi

pkg="qt5-$1"
repo="qt$1"
variant="${2:-mingw-w64}"
dest="${DEFAULT_PKGBUILDS_DIR}/${pkg}/${variant}"
wd="${QT_GIT_REPOS_DIR}/${repo}"

if ! [[ -d $wd ]]; then
    echo "\$QT_GIT_REPOS_DIR/$repo is no directory."
    exit -2
fi
if ! [[ -d $dest ]]; then
    echo "\$DEFAULT_PKGBUILDS_DIR/$pkg/${variant} is no directory."
    exit -3
fi

source "$dest/PKGBUILD"

new_sources=()
new_md5sums=()
file_index=0
for source in "${source[@]}"; do
    [ "${source: -6}" != .patch ] && \
        new_sources+=("$source") \
        new_md5sums+=("${sha256sums[$file_index]}")
    file_index=$((file_index + 1))
done

patches=("$dest"/*.patch)

for patch in "${patches[@]}"; do
    [[ -f $patch ]] && rm "$patch"
done

pushd "$wd" > /dev/null
git status # do some Git stuff just to check whether it is a Git repo
if ! git checkout "${pkgver}-${variant}"; then
    echo "No patches required for $1, skipping."
    exit 0
fi
git format-patch "v${pkgver}" --output-directory "$dest"
popd > /dev/null

new_patches=("$dest"/*.patch)
for patch in "${new_patches[@]}"; do
    new_sources+=("$patch")
    sum=$(sha256sum "$patch")
    new_md5sums+=(${sum%% *})
done

# preserve first src line to keep variables unevaluated
newsrc=$(grep 'source=(' "$dest/PKGBUILD")
[[ $newsrc ]] || newsrc="source=(${new_sources[0]}"
[ "${newsrc: -1:1}" == ')' ] && newsrc="${newsrc: 0:-1}" # truncate trailing )
for source in "${new_sources[@]:1}"; do
    newsrc+="\n        '${source##*/}'"
done
newsrc+=')'

newsums="sha256sums=('${new_md5sums[0]}'"
for sum in "${new_md5sums[@]:1}"; do
    newsums+="\n            '${sum}'"
done
newsums+=')'

# apply changes
mv "$dest/PKGBUILD" "$dest/PKGBUILD.bak"
awk -v newsrc="$newsrc" -v newsums="$newsums" '
    /^[[:blank:]]*source(_[^=]+)?=/,/\)[[:blank:]]*(#.*)?$/ {
        if (!s) {
            print newsrc
            s++
        }
        next
    }
    /^[[:blank:]]*(md|sha)[[:digit:]]+sums(_[^=]+)?=/,/\)[[:blank:]]*(#.*)?$/ {
        if (!w) {
            print newsums
            w++
        }
        next
    }

    1
    END {
        if (!s) {
            print newsrc
        }
        if (!w) {
            print newsums
        }
    }
' "$dest/PKGBUILD.bak" > "$dest/PKGBUILD"

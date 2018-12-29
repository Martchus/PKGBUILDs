#!/usr/bin/bash

# Imports patches from a Git repository to replace all currently present patches of a PKGBUILD

# setup shell environment
#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob
source /usr/share/makepkg/util/message.sh
colorize

# read arguments
if [[ ! $1 ]] || [[ ! $2 ]] || [[ ! $3 ]]; then
    echo 'Imports patches from a Git repository to replace all currently present patches of a PKGBUILD'
    echo "usage:   $0 path/to/PKGBUILD path/to/git-repo commit-range"
    echo "example: $0 ~/pkgbuilds/some-project/default/PKGBUILD ~/repos/some-project master..fixes-for-arch-package"
    echo "caveats: Only supports sha256sums (so far). Variables in other source lines than the first are not preserved."
    exit -1
fi
pkgbuild_file=$1
pkgbuild_dir=${pkgbuild_file%/*}
git_repo_path=$2
git_commit_range=$3
if [[ ! -f $pkgbuild_file ]]; then
    error "The specified PKGBUILD file \"$pkgbuild_file\" does not exist."
    exit -1
fi
if [[ ! -d $git_repo_path ]]; then
    error "The specified Git repository \"$git_repo_path\" does not exist."
    exit -2
fi

msg "Sourcing $pkgbuild_file"
source "$pkgbuild_file"

msg "Determine sources/checksums to be preserved"
new_sources=()
new_sha256sums=()
file_index=0
for source in "${source[@]}"; do
    # TODO: support other checksums than SHA-256
    if [ "${source: -6}" != .patch ]; then
        new_sources+=("$source")
        new_sha256sums+=("${sha256sums[$file_index]}")
        msg2 "$source; ${sha256sums[$file_index]}"
    fi
    file_index=$((file_index + 1))
done

msg "Removing old patches"
patches=("$pkgbuild_dir"/*.patch)
for patch in "${patches[@]}"; do
    if [[ -f $patch ]]; then
        msg2 "$patch"
        rm "$patch"
    fi
done

msg "Exporting patches"
[ "${pkgbuild_dir:0:1}" != / ] \
    && absolute_pkgbuild_dir=$PWD/$pkgbuild_dir \
    || absolute_pkgbuild_dir=$pkgbuild_dir
git -C "$git_repo_path" format-patch "$git_commit_range" --output-directory "$absolute_pkgbuild_dir"

msg "Determine new sources/checksums"
new_patches=("$pkgbuild_dir"/*.patch)
for patch in "${new_patches[@]}"; do
    new_sources+=("$patch")
    sum=$(sha256sum "$patch")
    sum=${sum%% *}
    new_sha256sums+=("$sum")
    msg2 "$patch; $sum"
done

msg "Adjust PKGBUILD file"
# preserve first src line to keep variables unevaluated
# FIXME: allow this for all sources which should be preserved
newsrc=$(grep 'source=(' "$pkgbuild_file")
[[ $newsrc ]] || newsrc="source=(${new_sources[0]}"
[ "${newsrc: -1:1}" == ')' ] && newsrc="${newsrc: 0:-1}" # truncate trailing )
# add sources
for source in "${new_sources[@]:1}"; do
    newsrc+="\n        '${source##*/}'"
done
newsrc+=')'
# add sha256sums
newsums="sha256sums=('${new_sha256sums[0]}'"
for sum in "${new_sha256sums[@]:1}"; do
    newsums+="\n            '${sum}'"
done
newsums+=')'
# apply changes
mv "$pkgbuild_file" "$pkgbuild_file.bak"
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
' "$pkgbuild_file.bak" > "$pkgbuild_file"

msg "Diff"
diff -Naur "$pkgbuild_file.bak" "$pkgbuild_file"

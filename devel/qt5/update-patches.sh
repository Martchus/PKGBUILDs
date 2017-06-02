#!/usr/bin/bash

# Copies patches from QT_GIT_REPOS_DIR to default
# variant of specified repo and outputs altered source and
# md5sums arrays

#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob

if ! [[ $1 ]]; then
    echo 'No Qt repo specified - must be specified like eg. base or multimedia.'
    exit -1
fi

pkg="qt5-$1"
repo="qt$1"
dest="${DEFAULT_PKGBUILDS_DIR}/${pkg}/mingw-w64"
wd="${QT_GIT_REPOS_DIR}/${repo}"

if ! [[ -d $wd ]]; then
    echo "\$QT_GIT_REPOS_DIR/$repo is no directory."
    exit -2
fi
if ! [[ -d $dest ]]; then
    echo "\$DEFAULT_PKGBUILDS_DIR/$pkg/mingw-w64 is no directory."
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
#for patch in "${patches[@]}"; do
#	new_sources+=("$patch")
#done

for patch in "${patches[@]}"; do
	[[ -f $patch ]] && rm "$patch"
done

pushd "$wd" > /dev/null
git checkout "${pkgver}-mingw-w64"
remote=
for maybe_remote in 'martchus' 'upstream'; do
	if git remote get-url $maybe_remote; then
		remote=$maybe_remote
		break
	fi
done
git format-patch "${remote}/${pkgver}" --output-directory "$dest"
popd > /dev/null

new_patches=("$dest"/*.patch)
for patch in "${new_patches[@]}"; do
	new_sources+=("$patch")
	sum=$(sha256sum "$patch")
	new_md5sums+=(${sum%% *})
done

echo -n "source=(\"${new_sources[0]}\""
for source in "${new_sources[@]:1}"; do
	echo
	echo -n "        '${source##*/}'"
done
echo ')'

echo -n "sha256sums=('${new_md5sums[0]}'"
for sum in "${new_md5sums[@]:1}"; do
	echo
	echo -n "            '${sum}'"
done
echo ')'

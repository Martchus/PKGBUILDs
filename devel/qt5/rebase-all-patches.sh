#!/usr/bin/bash

#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob
source /usr/share/makepkg/util/message.sh
colorize

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
new_version=$1
for r in "$QT_GIT_REPOS_DIR/qt"*; do
    repo="${r##*/qt}"
    [[ $repo == '5ct' || $repo == '5ct-code' || $repo == 'repotools' || $repo == 'webkit' ]] && continue
    pushd "$r" > /dev/null
    msg "Rebasing repository $repo ..."
    if [[ $(git branch | grep -- "$new_version-mingw-w64" | wc -l) -ge 1 ]]; then
        msg2 "Skipping $repo - branch $new_version-mingw-w64 already exists"
        continue
    fi
    "$scriptdir/rebase-patches.sh" "$@"
    popd > /dev/null
done

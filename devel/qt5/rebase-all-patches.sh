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
    in_loop=1 "$scriptdir/rebase-patches.sh" "$@"
    popd > /dev/null
done

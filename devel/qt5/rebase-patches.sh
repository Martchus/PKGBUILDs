#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob
source /usr/share/makepkg/util/message.sh
colorize

if ! [[ $1 ]] || ! [[ $2 ]]; then
    echo 'No version specified, must specify the new and old version, eg. 5.9.2 5.9.1'
    echo "Usage: $0 newversion oldversion [old-branch-suffix]"
    echo "Note: supposed to be run within the Qt Git checkout"
    exit -1
fi
newversion="$1"
oldversion="$2"
oldbranchsuffix="$3"

# determine branch from old version
oldversionbranch="$oldversion-mingw-w64"
[[ $oldbranchsuffix ]] && oldversionbranch_with_suffix="$oldversionbranch-$oldbranchsuffix"
branch_count=$(git branch | grep -- "$oldversionbranch_with_suffix" | wc -l)
if [[ $branch_count -lt 1 ]]; then
    msg2 "Trying without suffix because $oldversionbranch doesn't exist"
else
    oldversionbranch=$oldversionbranch_with_suffix
fi
branch_count=$(git branch | grep -- "$oldversionbranch" | wc -l)
if [[ $branch_count -lt 1 ]]; then
    msg2 "Branch for old version $oldversionbranch doesn't exist. Likely we just don't need any patches for this repo :-)"
    exit 0
fi
if [[ $branch_count -gt 1 ]]; then
    msg 'Which of the following branches was the latest for the old version?'
    git branch | grep "$oldversionbranch"
    msg2 'Please disambiguate by specifying the corresponding suffix as 3rd argument.'
    exit -1
fi

# determine remote to push
remote=
for maybe_remote in 'martchus' 'origin'; do
    if git remote get-url $maybe_remote; then
        remote=$maybe_remote
        break
    fi
done
if ! [[ $remote ]]; then
    error "Unable to detect remote"
    exit -2
fi

# update Git checkout, create new branch with rebased commits, push to remote
git remote update
git checkout -b "$newversion-mingw-w64" "origin/$newversion"
git cherry-pick "v$oldversion..$oldversionbranch"
git push -u $maybe_remote "$newversion-mingw-w64"

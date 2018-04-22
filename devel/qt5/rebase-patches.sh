#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob

if ! [[ $1 ]] || ! [[ $2 ]]; then
    echo 'No version specified, must specify the new and old version, eg. 5.9.2 5.9.1'
    echo "Usage: $0 newversion oldversion [old-branch-suffix]"
    exit -1
fi
newversion="$1"
oldversion="$2"
oldbranchsuffix="$3"

# determine branch from old version
oldversionbranch="$oldversion-mingw-w64"
if [[ $oldbranchsuffix ]] \
    && oldversionbranch="$oldversionbranch-$oldbranchsuffix"
if [[ $(git branch | grep "$oldversionbranch" | wc -l) -gt 1 ]]; then
    echo 'Which of the following branches was the latest for the old version?'
    git branch | grep "$oldversionbranch"
    echo 'Please disambiguate by specifying the corresponding suffix as 3rd argument.'
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
    echo "Unable to detect remote"
    exit -2
fi

# update Git checkout, create new branch with rebased commits, push to remote
git remote update
git checkout -b "$newversion-mingw-w64" "v$newversion"
git cherry-pick "v$oldversion..$oldversionbranch"
git push -u $maybe_remote "$newversion-mingw-w64"

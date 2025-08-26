#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob
source /usr/share/makepkg/util/message.sh
colorize

if ! [[ $1 ]] || ! [[ $2 ]]; then
    echo 'No version specified, must specify the new and old version, eg. 5.9.2 5.9.1'
    echo "Usage: $0 newversion oldversion [old-branch-suffix=mingw-w64] [new-branch-suffix=mingw-w64] [new-version-tag] [old-version-tag]"
    echo "Note: supposed to be run within the Qt Git checkout"
    exit -1
fi
newversion=$1
oldversion=$2
oldbranchsuffix=${3:-mingw-w64}
newbranchsuffix=${4:-mingw-w64}
newversiontag=$5
oldversiontag=$6

# check whether branch for new version already exists
newversionbranch=$newversion-$newbranchsuffix
branch_count=$(git branch | grep -- "$newversionbranch" | wc -l)
if [[ $branch_count -ge 1 ]]; then
    msg2 "Branch for new version $newversionbranch already exists. Likely already rebased (otherwise, use continue-rebase-patches.sh)."
    [[ $in_loop ]] && continue || exit -1
fi

# determine branch from old version
oldversionbranch=$oldversion-$oldbranchsuffix-fixes
branch_count=$(git branch | grep -- "$oldversionbranch" | wc -l)
if [[ $branch_count -lt 1 ]]; then
oldversionbranch=$oldversion-$oldbranchsuffix
branch_count=$(git branch | grep -- "$oldversionbranch" | wc -l)
if [[ $branch_count -lt 1 ]]; then
    msg2 "Branch for old version $oldversionbranch doesn't exist. Likely we just don't need any patches for this repo :-)"
    exit 0
fi
fi
if [[ -z $3 ]] && [[ $branch_count -gt 1 ]]; then
    msg 'Which of the following branches was the latest for the old version?'
    git branch | grep "$oldversionbranch"
    msg2 'Please disambiguate by specifying the corresponding suffix as 3rd argument.'
    exit -1
fi
msg2 "Basing new version $newversionbranch on $oldversionbranch"

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
if [[ $newversiontag ]]; then
    git checkout -b "$newversionbranch" "$newversiontag"
else
    git checkout -b "$newversionbranch" "origin/$newversion" || git checkout -b "$newversionbranch" "v$newversion"
fi
echo "Picking range: ${oldversiontag:-v$oldversion}..$oldversionbranch"
for prefix in 'echo' ''; do
    $prefix git cherry-pick "${oldversiontag:-v$oldversion}..$oldversionbranch"
    $preifx git push -u $maybe_remote "$newversionbranch"
done

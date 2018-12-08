#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob

if ! [[ $1 ]]; then
    echo 'No version specified, must specify the new version, eg. 5.9.2'
    echo "Usage: $0 newversion [new-branch-suffix=mingw-w64]"
    exit -1
fi
newversion="$1"
newbranchsuffix="${2:-mingw-w64}"

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

if ! git cherry-pick --continue; then
    echo "Seems like the cherry-pick has been concluded manually."
fi
git push -u $maybe_remote "$newversion-$newbranchsuffix"

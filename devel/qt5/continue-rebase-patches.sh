#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob

if ! [[ $1 ]] || ! [[ $2 ]]; then
    echo 'No version specified, must specify the new and old version, eg. 5.9.2 5.9.1'
    echo "Usage: $0 newversion"
    exit -1
fi
newversion="$1"

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

git cherry-pick --continue
git push -u $maybe_remote "$newversion-mingw-w64"

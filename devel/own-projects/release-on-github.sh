#!/usr/bin/bash
set -e # abort on first error
shopt -s nullglob
source versions.sh

# release latest version of my projects on GitHub (if not already released yet)
for project in "${!versions[@]}"
do
    version=${versions[$project]}
    gh_name=${github_names[$project]:-$project}
    [[ $gh_name == 'skip' ]] && continue
    [[ $version == 'none' ]] && continue
    echo '------------------------------------------------------------------------'
    echo "NEXT: $project -> $version"

    # check whether release already exists
    if github-release info --user martchus --repo "$gh_name" --tag "v$version"; then
        echo "auto-skipping $project -> v$version; release already present"
        continue
    fi

    # promt
    read -p "release $project -> v$version [y/n]? " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || continue

    # create release
    if github-release release --user martchus --repo "$gh_name" --tag "v$version"; then
        echo "SUCCESS: released $project -> $version"
    else
        echo "FAILURE: unable to create release $project -> $version"
        exit -1
    fi
done

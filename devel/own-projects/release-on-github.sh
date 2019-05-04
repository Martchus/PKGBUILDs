#!/bin/bash
set -e # abort on first error
shopt -s nullglob
source "$(dirname $0)/../versions.sh"

if ! [[ $GITHUB_TOKEN ]]; then
    echo "Don't forget to set \$GITHUB_TOKEN."
    exit -2
fi

gh_user=Martchus

# release latest version of my projects on GitHub (if not already released yet)
for project in "${!versions[@]}"
do
    version=${versions[$project]}
    gh_name=${github_names[$project]:-$project}
    [[ $gh_name == 'skip' ]] && continue
    [[ $version == 'none' ]] && continue
    echo '------------------------------------------------------------------------'
    echo "NEXT: $project -> $version"

    # check whether CMakeLists.txt has been updated
    cmake_lists=$(wget -qO- "https://raw.githubusercontent.com/$gh_user/$gh_name/master/CMakeLists.txt")
    major_version_regex='set\(META_VERSION_MAJOR ([^\)]*)\)'
    minor_version_regex='set\(META_VERSION_MINOR ([^\)]*)\)'
    patch_version_regex='set\(META_VERSION_PATCH ([^\)]*)\)'
    cmake_version=
    if ! [[ $cmake_lists =~ $major_version_regex ]]; then
        echo "FAILURE: Unable to read major version from CMakeLists.txt:\n$cmake_lists"
        continue
    fi
    cmake_version=${BASH_REMATCH[1]}
    if ! [[ $cmake_lists =~ $minor_version_regex ]]; then
        echo "FAILURE: Unable to read minor version from CMakeLists.txt:\n$cmake_lists"
        continue
    fi
    cmake_version=$cmake_version.${BASH_REMATCH[1]}
    if ! [[ $cmake_lists =~ $patch_version_regex ]]; then
        echo "FAILURE: Unable to read patch version from CMakeLists.txt:\n$cmake_lists"
        continue
    fi
    cmake_version=$cmake_version.${BASH_REMATCH[1]}
    if [[ $version != $cmake_version ]]; then
        echo "FAILURE: Unable to release $project -> v$version; CMake version is v$cmake_version"
        continue
    fi

    # check whether release already exists
    if github-release info --user "$gh_user" --repo "$gh_name" --tag "v$version"; then
        echo "auto-skipping $project -> v$version; release already present"
        continue
    fi

    # promt
    read -p "release $project -> v$version [y/n]? " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || continue

    # create release
    if github-release release --user "$gh_user" --repo "$gh_name" --tag "v$version"; then
        echo "SUCCESS: released $project -> $version"
    else
        echo "FAILURE: unable to create release $project -> $version"
        exit -1
    fi
done

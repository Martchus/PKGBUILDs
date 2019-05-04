#!/bin/bash
set -e # abort on first error
shopt -s nullglob
source "$(dirname $0)/../versions.sh"

repo_dir=${PATH_REPO_OWNSTUFF}
if ! [[ $repo_dir ]]; then
    echo "\$PATH_REPO_OWNSTUFF is empty."
    exit -1
fi
repo_dir+='/x86_64'
if ! [[ -d $repo_dir ]]; then
    echo "\$PATH_REPO_OWNSTUFF/x86_64 does not point to a directory."
    exit -1
fi

# upload latest static mingw-w64 package of my projects on GitHub (if not already present)
for project in "${!versions[@]}"
do
    version=${versions[$project]}
    gh_name=${github_names[$project]:-$project}
    [[ $gh_name == 'skip' ]] && continue
    [[ $version == 'none' ]] && continue
    echo '------------------------------------------------------------------------'
    echo "NEXT: $project/v$version"

    # determine file path of arch linux package
    pkg_files=("$repo_dir/mingw-w64-$project-$version"-*-*.pkg.tar.xz)
    if [[ ${#pkg_files[@]} == 0 ]]; then
        echo "no mingw-w64 package for $project/v$version present"
        continue
    fi
    latest_pkg_file=${pkg_files[-1]}

    # extract arch linux package
    pkg_file_name=${latest_pkg_file##*/}
    temp_dir=$(mktemp -d -t "$pkg_file_name-XXXXXXXXXX")
    pushd "$temp_dir"

    # make a zip file for each statically linked binary
    bsdtar xJf "$latest_pkg_file"
    zip_files=()
    for arch in i686-w64-mingw32 x86_64-w64-mingw32; do
        binaries=(usr/$arch/bin/*-static.exe)
        for binary in ${binaries[@]}; do
            binary_name=${binary##*/}
            binary_name=${binary_name%-static.exe}-$version-$arch
            echo "zipping $binary to $binary_name.zip"
            mv "$binary" "$binary_name.exe"
            bsdtar acf "$binary_name.zip" "$binary_name.exe"
            zip_files+=("$binary_name.zip")
        done
    done

    # upload created zip files
    if [[ ${#zip_files[@]} == 0 ]]; then
        echo "no zip files for $project/v$version could be created"
        continue
    fi
    for zip_file in ${zip_files[@]}; do
        # check whether upload already exists
        if github-release info --user martchus --repo "$gh_name" --tag "v$version" | grep "artifact: $zip_file"; then
            echo "auto-skipping $project/v$version; $zip_file already present"
            continue
        fi

        # upload file
        echo "uploading $project/v$version -> $zip_file"
        if github-release upload --user martchus --repo "$gh_name" --tag "v$version" --file "$zip_file" --name "$zip_file"; then
            echo "SUCCESS: uploaded $project/v$version -> $zip_file"
        else
            echo "FAILURE: unable to upload $project/v$version -> $zip_file"
            exit -1
        fi
    done

    popd
    rm -r "$temp_dir"
done

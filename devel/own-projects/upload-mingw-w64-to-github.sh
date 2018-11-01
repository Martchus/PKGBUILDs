#!/bin/bash
set -e # abort on first error
shopt -s nullglob
source versions.sh

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

    # determine file path
    files=("$repo_dir/mingw-w64-$project-static-$version"-*-*.pkg.tar.xz)
    if [[ ${#files[@]} == 0 ]]; then
        echo "no static mingw-w64 package for $project/v$version present"
        continue
    fi
    latest_file=${files[-1]}
    file_name=${latest_file##*/}

    # check whether upload already exists
    if github-release info --user martchus --repo "$gh_name" --tag "v$version" | grep "artifact: $file_name"; then
        echo "auto-skipping $project/v$version; $latest_file already present"
        continue
    fi

    # upload file
    echo "uploading $project/v$version -> $latest_file"
    if github-release upload --user martchus --repo "$gh_name" --tag "v$version" --file "$latest_file" --name "$file_name"; then
        echo "SUCCESS: uploaded $project/v$version -> $latest_file"
    else
        echo "FAILURE: unable to upload $project/v$version -> $latest_file"
        exit -1
    fi
done

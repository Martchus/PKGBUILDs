#!/bin/bash
set -e # abort on first error
shopt -s nullglob
source "$(dirname $0)/../versions.sh"

gh_user=Martchus
new_release_date=$(date --iso-8601)
old_release_date_regex='set\(META_RELEASE_DATE "([^\)]*)"\)'

# read project dirs; split colon separated path
OIFS=$IFS
IFS=':'
for dir in $DEFAULT_PROJECTS_DIR; do
    projectsdirs+=("$dir")
done
IFS=$OIFS

# check whether the project will be released and set the current day as release date then
for project in "${!versions[@]}"
do
    version=${versions[$project]}
    gh_name=${github_names[$project]:-$project}
    [[ $gh_name == 'skip' ]] && continue
    [[ $version == 'none' ]] && continue
    echo '------------------------------------------------------------------------'
    echo "NEXT: $project -> $version"

    # check whether release already exists
    if github-release info --user "$gh_user" --repo "$gh_name" --tag "v$version"; then
        echo "skipping $project -> v$version; release already present"
        continue
    fi

    # locate project
    project_dir=
    for dir in "${projectsdirs[@]}"; do
        [[ -d $dir/$project ]] && project_dir=$dir/$project && break
    done
    if [[ ! $project_dir ]]; then
        echo "FAILURE: Unable to locate checkout of $project"
        continue
    fi
    echo "entering '$project_dir'"
    cd "$project_dir"

    # check current release date

    [[ -f CMakeLists.txt ]] || continue
    cmake_lists=$(cat CMakeLists.txt)
    if ! [[ $cmake_lists =~ $old_release_date_regex ]]; then
        echo "FAILURE: Unable to read current release date from CMakeLists.txt:\n$cmake_lists"
        continue
    fi
    old_release_date=${BASH_REMATCH[1]}
    if [[ $old_release_date == "$new_release_date" ]]; then
        echo "skipping $project -> release date $old_release_date does not change"
        continue
    fi

    if ! [ -z "$(git status --porcelain)" ]; then
        echo "FAILURE: Git checkout '$PWD' is not clean"
        continue
    fi

    # promt
    read -p "update release date of $project -> v$version [y/n]? " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || continue

    # update release date
    sed -i -e "s|set(META_RELEASE_DATE.*|set(META_RELEASE_DATE \"$new_release_date\")|" CMakeLists.txt
    git add CMakeLists.txt
    git commit -m 'Update release date'
    git push
done

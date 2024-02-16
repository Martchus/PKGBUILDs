#!/bin/bash
set -e # abort on first error
shopt -s nullglob
source "$(dirname $0)/../versions.sh"

if ! [[ -d $OSC_DIR ]]; then
    echo "\$OSC_DIR is set to \"$OSC_DIR\" which is not a directory."
    exit 1
fi

for spec_file in "$OSC_DIR"/*/*/*.spec; do
    trimmed_path=${spec_file#$OSC_DIR/*/*/}
    project_name=${trimmed_path%*.spec}
    project_name=${project_name%-qt6}
    spec_dir=${spec_file%/*}

    # skip packages with unknown version
    version=${versions[$project_name]}
    [[ $version ]] || continue

    echo "NEXT: $project_name -> $version"
    echo '------------------------------------------------------------------------------------------'

    # apply new version
    sed -i -e "s/Version:        .*/Version:        $version/" "$spec_file"
    chmod 644 "$spec_file"

    # push changes with osc
    pushd "$spec_dir"
    if ! [[ -f ../update-osc-repo.sh ]]; then
        echo "skip updating osc repo for $project_name: update script not present in ${spec_dir%/*}"
    elif [[ $(osc diff) ]]; then
        ../update-osc-repo.sh "Update to $version"
        echo "updated $project_name.spec -> $version"
    else
        echo "skip updating osc repo for $project_name: no changes made"
    fi
    popd
done

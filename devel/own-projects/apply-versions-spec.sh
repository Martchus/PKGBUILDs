#!/usr/bin/bash
set -e # abort on first error
shopt -s nullglob
source versions.sh

for spec_file in "$OSC_DIR"/*/*/*.spec; do
    trimmed_path=${pkgbuild_file#$OSC_DIR/}
    project_name=${trimmed_path%%/*}

    # TODO

    echo "$trimmed_path -> $version"
done

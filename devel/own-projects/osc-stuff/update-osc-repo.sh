#!/bin/bash

set -e # fail on error

msg="$1"
pkg="$2"

if [[ ! $msg ]]; then
    echo 'No commit message specified.'
    exit -2
fi

[[ $pkg ]] && pushd "$pkg"

if [[ $(osc status) == "" ]]; then
    echo 'No local changes to check in.'
    exit -3
fi

[ ! -f *.changes ] && no_changes_yet=1

if ! [[ $NO_DOWNLOAD ]]; then
    osc rm *.tar.gz
    osc service localrun download_files
    osc add *.tar.gz
fi
osc service localrun format_spec_file
osc vc -m "$1"
[[ $no_changes_yet ]] && osc add *.changes
osc ci -m "$1"

[[ $pkg ]] && popd
exit 0

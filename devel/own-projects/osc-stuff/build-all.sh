#!/bin/bash

set -e # fail on error

for d in c++utilities qtutilities passwordfile passwordmanager tagparser tageditor syncthingtray; do
    pushd $d
    tw
    popd
done

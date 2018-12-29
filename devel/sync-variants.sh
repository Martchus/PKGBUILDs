#!/usr/bin/bash

# Syncs different variants of a PKGBUILD

# setup shell environment
#set -euxo pipefail
set -e # abort on first error
shopt -s nullglob
shopt -s extglob
export BASHOPTS
source /usr/share/makepkg/util/message.sh
colorize

# declare (variant-specific) variables to be preserved
variables_to_preserve=(
    pkgname
    _pkg_arch
    _android_arch
    _android_platform
    _android_platform_arch
    _android_api_level
    _boost_arch
    _boost_address_model
)

# read arguments
if [[ ! $1 ]] || [[ ! $2 ]] || [[ ! $3 ]]; then
    echo 'Syncs different variants of a PKGBUILD'
    echo "Usage:   $0 path/to/variants master-variant variants-to-adjust"
    echo "example: $0 ~/pkgbuilds/qt5-base mingw-w64 mingw-w64-{static,angle,dynamic}"
    echo "example: $0 ~/pkgbuilds/qt5-base android-aarch64 android-*"
    exit -1
fi
path=$1
master=$2
shift 2
if [[ ! -d $path ]]; then
    error "Variant-path \"$path\" does not exist."
    exit -1
fi
if [[ ! -d $path/$master ]]; then
    error "Master \"$master\" does not exist in \"$path\"."
    exit -1
fi

# determine variant dirs (using $(echo ...) to apply glob)
pushd "$path" > /dev/null
variant_dirs=("$@")
variant_dirs=($(echo ${variant_dirs[@]}))

# sync variant dirs with master
for variant_dir in "${variant_dirs[@]}"; do
    # skip test packages
    [[ $variant_dir == *'-test' ]] && continue

    # prevent syncing master with itself
    [[ $variant_dir == $master ]] && continue

    msg "Sync $path/$master -> $path/$variant_dir"

    # ensure variant dir exists
    if [[ ! -d $variant_dir ]]; then
        warning "Creating $path/$variant_dir because it doesn't exist yet; won't be able to preserve any variables"
        mkdir "$variant_dir"
    fi

    # read values to preserve (use sed rather than just sourcing to preserve variables)
    msg2 "Saving values to preserve"
    if [[ -f $variant_dir/PKGBUILD ]]; then
        declare -A values_to_preserve=()
        for variable_to_preserve in "${variables_to_preserve[@]}"; do
            value=$(sed -n -e "/^${variable_to_preserve}=.*$/p" "$variant_dir/PKGBUILD" | sed -E 's/([\:#$%&\-\])/\\\1/g')
            values_to_preserve[$variable_to_preserve]=${value#${variable_to_preserve}=}
            [[ $value ]] && plain " - $value"
            # note: Last sed to escape special characters is required because the value is later passed again to sed as replacement value.
        done
    else
        warning "\"$path/$variant_dir/PKGBUILD\" does not exist; unable to preserve variables"
    fi

    msg2 "Replace files"
    if [ "$variant_dir/"* ]; then
        rm "$variant_dir/"* # clean existing files first (files might have been removed in master and we don't want any leftovers)
    fi
    cp "$master/"* "$variant_dir"

    msg2 "Restore values to preserve"
    sed_args=()
    for variable_to_preserve in "${variables_to_preserve[@]}"; do
        sed_args+=('-e' "s:^${variable_to_preserve}=.*$:${variable_to_preserve}=${values_to_preserve[$variable_to_preserve]}:")
        # if we would have just sourced the variant PKGBUILD:
        # sed_args+=('-e' "s/^${variable_to_preserve}=.*$/${variable_to_preserve}=${!variable_to_preserve}/")
    done
    sed "${sed_args[@]}" "$master/PKGBUILD" > "$variant_dir/PKGBUILD"
done

popd > /dev/null

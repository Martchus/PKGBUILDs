#!/bin/bash
set -e # abort on first error
shopt -s nullglob
shopt -s extglob
source "$(dirname $0)/../versions.sh"

if ! [[ $DRY_RUN ]] && ! [[ $GITHUB_TOKEN ]]; then
    echo "Don't forget to set \$GITHUB_TOKEN."
    exit -2
fi

if [[ $DRY_RUN ]]; then
    target=${DRY_RUN_TARGET:-$PWD} 
fi

projects=(${PROJECTS:-${!versions[@]}})

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
for project in "${projects[@]}"
do
    version=${versions[$project]}
    gh_name=${github_names[$project]:-$project}
    [[ $gh_name == 'skip' ]] && continue
    [[ $version == 'none' ]] && continue
    echo '------------------------------------------------------------------------'
    echo "NEXT: $project/v$version"
    temp_dir=$(mktemp -d -t "$project-XXXXXXXXXX")
    zip_files=()
    pushd "$temp_dir"

    for variant in '' 'qt6'; do
    [[ $variant ]] && variant_suffix=-$variant || variant_suffix=

    # determine file path of arch linux package
    pkg_name=mingw-w64-$project$variant_suffix
    pkg_files=("$repo_dir/$pkg_name-$version"-*-*.pkg.tar.!(*.sig))
    if [[ ${#pkg_files[@]} == 0 ]]; then
        echo "no mingw-w64$variant_suffix package for $project/v$version present"
        continue
    fi
    latest_pkg_file=${pkg_files[-1]}

    # extract arch linux package
    pkg_file_name=${latest_pkg_file##*/}
    bsdtar xJf "$latest_pkg_file"

    # locate the license file
    license_file=usr/share/licenses/$pkg_name/LICENSES-windows-distribution.md
    if [[ ! -f $license_file ]]; then
        echo "the package $latest_pkg_file does not include the expected license file $license_file"
        continue
    fi

    # make a zip file for each statically linked binary
    for arch in i686-w64-mingw32 x86_64-w64-mingw32; do
        binaries=(usr/$arch/bin/*-static.exe)
        for binary in ${binaries[@]}; do
            base_name=${binary##*/}
            base_name=${base_name%-static.exe}
            symlink_name=$base_name-$arch.exe
            # consider Qt 6 the suffixless default and use suffix for Qt 5 version instead
            if  [[ $base_name =~ .*-qt6 ]]; then
                base_name=${base_name%-qt6}
            else
                base_name=${base_name}-qt5
            fi
            binary_name=$base_name-$version-$arch.exe

            # check whether upload already exists
            zip_file="$binary_name.zip"
            if ! [[ $DRY_RUN ]] && github-release info --user martchus --repo "$gh_name" --tag "v$version" | grep "artifact: $zip_file"; then
                echo "auto-skipping $project/v$version; $zip_file already present"
                continue
            elif [[ $DRY_RUN ]] && [[ -e $zip_file ]]; then
                echo "auto-skipping $project/v$version; $zip_file already present (dry-run)"
                continue
            fi

            # create zip file
            echo "zipping $binary to $zip_file"
            mv "$binary" "$binary_name"
            ln -s "$binary_name" "$symlink_name"
            license_file_2=$project-$version-$arch-LICENSES.md
            cp "$license_file" "$license_file_2"
            bsdtar acf "$zip_file" "$binary_name" "$license_file_2"
            zip_files+=("$zip_file")
        done
    done
    done
    pkg_name=static-compat-$project
    pkg_files=("$repo_dir/$pkg_name-$version"-*-*.pkg.tar.!(*.sig))
    if [[ ${#pkg_files[@]} == 0 ]]; then
        echo "no static-compat package for $project/v$version present"
    else
        latest_pkg_file=${pkg_files[-1]}

        # extract arch linux package
        pkg_file_name=${latest_pkg_file##*/}
        bsdtar xJf "$latest_pkg_file"

        # locate the license file
        license_file=usr/share/licenses/$pkg_name/LICENSES-linux-distribution.md
        if [[ ! -f $license_file ]]; then
            echo "the package $latest_pkg_file does not include the expected license file $license_file"
        fi

        binaries=(usr/static-compat/bin/*)
        arch=x86_64-pc-linux-gnu
        for binary in ${binaries[@]}; do
            base_name=${binary##*/}
            symlink_name=$base_name-$arch
            binary_name=$base_name-$version-$arch

            # check whether upload already exists
            zip_file="$binary_name.tar.xz"
            if ! [[ $DRY_RUN ]] && github-release info --user martchus --repo "$gh_name" --tag "v$version" | grep "artifact: $zip_file"; then
                echo "auto-skipping $project/v$version; $zip_file already present"
                continue
            elif [[ $DRY_RUN ]] && [[ -e $zip_file ]]; then
                echo "auto-skipping $project/v$version; $zip_file already present (dry-run)"
                continue
            fi

            # create zip file
            echo "zipping $binary to $zip_file"
            mv "$binary" "$binary_name"
            ln -s "$binary_name" "$symlink_name"
            #license_file_2=$project-$version-$arch-LICENSES.md
            #cp "$license_file" "$license_file_2"
            bsdtar acf "$zip_file" "$binary_name" "$symlink_name"
            zip_files+=("$zip_file")
        done
    fi

    # upload created zip files
    if [[ ${#zip_files[@]} == 0 ]]; then
        echo "no zip files for $project/v$version could be created (either all skipped or no executables found)"
        continue
    fi

    # upload files
    for zip_file in ${zip_files[@]}; do
        echo "uploading $project/v$version -> $zip_file"
        if [[ $DRY_RUN ]]; then
            mv --target-directory="$target" "$zip_file" 
            continue
        fi
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

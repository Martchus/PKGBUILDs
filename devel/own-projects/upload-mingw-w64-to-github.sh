#!/bin/bash
set -e # abort on first error
shopt -s nullglob
shopt -s extglob
path=$(realpath "$(dirname $0)")
source "$path/../versions.sh"

if ! [[ $DRY_RUN ]] && ! [[ $GITHUB_TOKEN ]]; then
    echo "Don't forget to set \$GITHUB_TOKEN."
    exit 1
fi
if ! [[ $DRY_RUN ]] && ! [[ $RELEASE_KEY_PW ]]; then
    echo "Don't forget to set \$RELEASE_KEY_PW."
    exit 1
fi

# determine GPGKEY to use and test signing
if [[ -f /etc/makepkg.conf ]]; then
    source /etc/makepkg.conf
fi
if ! [[ $GPGKEY ]] && ! [[ $SKIP_SIGNING ]]; then
    echo "You must set \$GPGKEY for signing or \$SKIP_SIGNING to skip signing."
    exit 2
fi
if [[ -n $GPGKEY ]]; then
    # make helpers for signing used by buildservice available to this script as well
    export PATH=/var/lib/buildservice-git/bin:/var/lib/buildservice:$PATH
    SIGNWITHKEY=(-u "${GPGKEY}")
    echo 'test' > /tmp/signing-test
    if ! gpg --detach-sign --yes --use-agent "${SIGNWITHKEY[@]}" --no-armor /tmp/signing-test ; then
        echo 'Not continuing, setup for signing is broken'
        exit 3
    fi
    rm /tmp/signing-test*
    echo "Will sign archives with key ${GPGKEY}"
fi

# determine keyfile for signing via stsigtool
stsigtool=stsigtool

release_signing_keyfile_stsigtool_enc=$DOCS_DIR/keys/release-signing/private-stsigtool.pem.enc
release_signing_keyfile_openssl_enc=$DOCS_DIR/keys/release-signing/private-openssl-secp521r1.pem.enc
[[ ! -e $release_signing_keyfile_stsigtool_enc ]] && echo "Unable to find $release_signing_keyfile_stsigtool_enc" && exit 3
[[ ! -e $release_signing_keyfile_openssl_enc ]] && echo "Unable to find $release_signing_keyfile_openssl_enc" && exit 3

home_tmp=$HOME/tmp/release-signing
mkdir -p "$home_tmp"
chmod 700 "$home_tmp"
release_signing_keyfile_stsigtool=$home_tmp/private-stsigtool.pem
release_signing_keyfile_openssl=$home_tmp/private-openssl-secp521r1.pem
trap "rm -f $release_signing_keyfile_stsigtool $release_signing_keyfile_openssl" EXIT

openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass env:RELEASE_KEY_PW -in "$release_signing_keyfile_stsigtool_enc" -out "$release_signing_keyfile_stsigtool"
openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass env:RELEASE_KEY_PW -in "$release_signing_keyfile_openssl_enc" -out "$release_signing_keyfile_openssl"

sign_openssl() {
    in=$1 out=$2
    echo "-----BEGIN SIGNATURE-----" > "$out"
    openssl dgst -sha256 -sign "$release_signing_keyfile_openssl" "$in" | base64 -w 64 >> "$out"
    echo "-----END SIGNATURE-----" >> "$out"
}

if [[ $DRY_RUN ]]; then
    target=${DRY_RUN_TARGET:-$PWD} 
fi

projects=(${PROJECTS:-${!versions[@]}})
errors=()

if [[ $EXPERIMENTAL ]]; then
    repo_dir=${PATH_REPO_OWNSTUFF_EXPERIMENTAL}
elif [[ $TESTING ]]; then
    repo_dir=${PATH_REPO_OWNSTUFF_TESTING}
else
    repo_dir=${PATH_REPO_OWNSTUFF}
fi
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

        # handle mingw-w64 packages
        mingw_w64_pkg=(mingw-w64{,-clang-aarch64}-$project$variant_suffix)
        for pkg_name in "${mingw_w64_pkg[@]}"; do
            # determine file path of arch linux package
            pkg_files=("$repo_dir/$pkg_name-$version"-*-*.pkg.tar.!(*.sig))
            if [[ ${#pkg_files[@]} == 0 ]]; then
                echo "no package $pkg_name for $project/v$version present"
                continue
            fi
            latest_pkg_file=${pkg_files[-1]}
            echo "using package $latest_pkg_file for $project$variant_suffix"

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
            for arch in i686-w64-mingw32 x86_64-w64-mingw32 aarch64-w64-mingw32; do
                binaries=(usr/$arch/bin/*-static.exe)
                for binary in ${binaries[@]}; do
                    binary_cli=${binary%-static.exe}-static-cli.exe
                    base_name=${binary##*/}
                    base_name=${base_name%-static.exe}
                    # consider Qt 6 the suffixless default and use suffix for Qt 5 version instead
                    if  [[ $base_name =~ .*-qt6 ]]; then
                        base_name=${base_name%-qt6}
                    else
                        base_name=${base_name}-qt5
                    fi
                    binary_name=$base_name.exe # used to be $base_name-$version-$arch.exe
                    binary_name_cli=$base_name-cli.exe # used to be $base_name-$version-$arch-cli.exe

                    # check whether upload already exists
                    zip_file=$base_name-$version-$arch.exe.zip
                    if ! [[ $DRY_RUN ]] && github-release info --user martchus --repo "$gh_name" --tag "v$version" | grep "artifact: $zip_file"; then
                        echo "auto-skipping $project/v$version; $zip_file already present"
                        continue
                    elif [[ $DRY_RUN ]] && [[ -e $zip_file ]]; then
                        echo "auto-skipping $project/v$version; $zip_file already present (dry-run)"
                        continue
                    fi

                    # check whether exe is actually self-contained
                    binaries=("$binary")
                    [[ -e $binary_cli ]] && binaries+=("$binary_cli")
                    if "$path/is-self-contained-exe.sh" "${binaries[@]}"; then
                        echo "$binary is self-contained"
                    else
                        echo "skipping $binary as it is not self-contained"
                        errors+=("$binary as it is not self-contained")
                        continue
                    fi

                    # create zip file
                    echo "zipping $binary to $zip_file"
                    mv "$binary" "$binary_name"
                    "$stsigtool" sign "$release_signing_keyfile_stsigtool" "$binary_name" > "$binary_name.stsigtool.sig"
                    sign_openssl "$binary_name" "$binary_name.openssl.sig"
                    additional_files=("$binary_name.stsigtool.sig" "$binary_name.openssl.sig")
                    if [[ -f $binary_cli ]]; then
                        mv "$binary_cli" "$binary_name_cli"
                        "$stsigtool" sign "$release_signing_keyfile_stsigtool" "$binary_name_cli" > "$binary_name_cli.stsigtool.sig"
                        sign_openssl "$binary_name_cli" "$binary_name_cli.openssl.sig"
                        additional_files+=("$binary_name_cli" "$binary_name_cli.stsigtool.sig" "$binary_name_cli.openssl.sig")
                    fi
                    license_file_2=$project-$version-$arch-LICENSES.md
                    cp "$license_file" "$license_file_2"
                    bsdtar acf "$zip_file" "$binary_name" "$license_file_2" "${additional_files[@]}"
                    zip_files+=("$zip_file")
                done
            done
        done
    done

    # handle static-compat packages
    pkg_name=static-compat-$project
    pkg_files=("$repo_dir/$pkg_name-$version"-*-*.pkg.tar.!(*.sig))
    if [[ ${#pkg_files[@]} == 0 ]]; then
        echo "no static-compat package for $project/v$version present"
    else
        latest_pkg_file=${pkg_files[-1]}
        echo "using package $latest_pkg_file for $project"

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
            binary_name=$base_name # used to be $base_name-$version-$arch

            # check whether upload already exists
            zip_file=$base_name-$version-$arch.tar.xz
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
            "$stsigtool" sign "$release_signing_keyfile_stsigtool" "$binary_name" > "$binary_name.stsigtool.sig"
            sign_openssl "$binary_name" "$binary_name.openssl.sig"
            #license_file_2=$project-$version-$arch-LICENSES.md
            #cp "$license_file" "$license_file_2"
            bsdtar acf "$zip_file" "$binary_name" "$binary_name.stsigtool.sig" "$binary_name.openssl.sig"
            zip_files+=("$zip_file")
        done
    fi

    # try next project and print warning if no files could be created
    if [[ ${#zip_files[@]} == 0 ]]; then
        echo "no zip files for $project/v$version could be created (either all skipped or no executables found)"
        continue
    fi

    # sign files
    to_upload=()
    for zip_file in ${zip_files[@]}; do
        to_upload+=("$zip_file")
        if ! [[ $GPGKEY ]]; then
            continue
        fi
        echo "signing $project/v$version -> $zip_file"
        gpg --detach-sign --yes --use-agent "${SIGNWITHKEY[@]}" --no-armor "$zip_file"
        to_upload+=("$zip_file.sig")
    done

    # upload files
    for zip_file in ${to_upload[@]}; do
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

for error in "${errors[@]}"; do echo "error: $error"; done
[[ ${errors[@]} == 0 ]] && exit 0 || exit 1

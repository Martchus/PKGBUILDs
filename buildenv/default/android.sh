#!/usr/bin/bash

# This file is no longer included as it leads to ANDROID_MINIMUM_PLATFORM being
# cleared with `!buildflags` and that option is necessary in android-* packages.
# So builds are relying on having the variable in `/etc/makepkg.conf`.

[[ -n "$LIBMAKEPKG_BUILDENV_ANDROID_SH" ]] && return
LIBMAKEPKG_BUILDENV_ANDROID_SH=1

buildenv_functions+=('buildenv_android')
buildenv_vars+=('ANDROID_MINIMUM_PLATFORM')

buildenv_android() {
	# set minimum Android version to Android 7.0
	ANDROID_MINIMUM_PLATFORM=24
}

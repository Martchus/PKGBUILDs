#!/usr/bin/bash

[[ -n "$LIBMAKEPKG_BUILDENV_PARALLEL_SH" ]] && return
LIBMAKEPKG_BUILDENV_PARALLEL_SH=1

buildenv_functions+=('buildenv_parallel')

buildenv_parallel() {
	[[ $MAKEFLAGS ]] || MAKEFLAGS=-j$(nproc)
}

#!/bin/sh

# check if last arg is a path to configure, else use parent
for last; do true; done
if test -x "${last}/configure"; then
  config_path="$last"
elif [[ -e ./configure ]]; then
  config_path=.
else
  config_path=..
fi

source static-compat-environment

${config_path}/configure \
  --prefix="$static_compat_prefix" \
  --libdir="$static_compat_prefix/lib" \
  --includedir="$static_compat_prefix/include" \
  "$@"

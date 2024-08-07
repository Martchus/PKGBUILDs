#!/bin/bash

. /usr/bin/mingw-clang-env @TRIPLE@

# check if last arg is a path to configure, else use parent
for last; do true; done
if test -x "${last}/configure"; then
  config_path="$last"
else
  config_path=".."
fi

${config_path}/configure \
  --host=@TRIPLE@ --target=@TRIPLE@ --build="$CHOST" \
  --prefix=/usr/@TRIPLE@ --libdir=/usr/@TRIPLE@/lib --includedir=/usr/@TRIPLE@/include \
  --enable-shared --enable-static "$@"

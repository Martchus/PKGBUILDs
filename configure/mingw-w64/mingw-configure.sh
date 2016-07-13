#!/bin/sh

# check if last arg is a path to configure, else use parent
for last; do true; done
if test -x "${last}/configure"
then
  config_path="$last"
else
  config_path=".."
fi

mingw_flags="${CUSTOM_MINGW_FLAGS:--O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions --param=ssp-buffer-size=4}"
LDFLAGS=""
export CFLAGS="$mingw_flags $CFLAGS"
export CXXFLAGS="$mingw_flags $CXXFLAGS"
${config_path}/configure --host=@TRIPLE@ --target=@TRIPLE@ --build="$CHOST" \
  --prefix=/usr/@TRIPLE@ --libdir=/usr/@TRIPLE@/lib --includedir=/usr/@TRIPLE@/include \
  --enable-shared --enable-static "$@"

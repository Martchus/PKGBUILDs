#!/bin/bash

. /usr/bin/mingw-clang-env @TRIPLE@

# check if last arg is a path to configure, else use parent
for last; do true; done
if test -x "${last}/configure"; then
  config_path="$last"
else
  config_path=".."
fi

# let check for recognizing dependent libraries always pass
# note: This is logged as "checking how to recognize dependent libraries... file_magic ^x86 archive import|^x86 DLL" and
#       obviously not going to work when targeting e.g. aarch64.
sed -i -e 's|file_magic.*DLL|pass_all|g' ${config_path}/configure

${config_path}/configure \
  --host=@TRIPLE@ --target=@TRIPLE@ --build="$CHOST" \
  --prefix=/usr/@TRIPLE@ --libdir=/usr/@TRIPLE@/lib --includedir=/usr/@TRIPLE@/include \
  --enable-shared --enable-static "$@"

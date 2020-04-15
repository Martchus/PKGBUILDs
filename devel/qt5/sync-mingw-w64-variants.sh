#!/usr/bin/bash -e
"$(dirname "$0")/../sync-variants.sh" qt5-base mingw-w64 mingw-w64-{static,opengl,angle,dynamic}

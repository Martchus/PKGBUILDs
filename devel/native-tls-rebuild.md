# Enabling native TLS in mingw-w64-gcc

## Steps
Install all `mingw-w64` in chroot and run the following script to detect packages that need to be rebuilt:
```
$ cat /tmp/detect.sh
#!/bin/bash
# Detect mingw-w64 DLLs (x86_64 only) built with old emulated TLS (pre --enable-tls)
# - CRITICAL: imports __emutls_v.* from libstdc++-6.dll -> fails on Win32 with gcc>=15.1/16.2 (native TLS)
# - WARNING: imports __emutls_get_address from libgcc_s_seh-1.dll -> still loads but emulated/slow
set -e
echo "=== CRITICAL (x86_64, will fail on Windows) ==="
for f in /usr/x86_64-w64-mingw32/bin/*.dll; do
  [ -e "$f" ] || continue
  x86_64-w64-mingw32-objdump -p "$f" 2>/dev/null | grep -q '__emutls_v\.' && echo "NEED REBUILD: $f ($(pacman -Qo "$f" 2>/dev/null | cut -d' ' -f5- || echo unknown))"
done | sort -u
echo
echo "=== ALL emutls users (x86_64, CRITICAL+WARNING) ==="
for f in /usr/x86_64-w64-mingw32/bin/*.dll; do
  [ -e "$f" ] || continue
  x86_64-w64-mingw32-objdump -p "$f" 2>/dev/null | grep -q '__emutls' && echo "$f ($(pacman -Qo "$f" 2>/dev/null | cut -d' ' -f5- || echo unknown))"
done | sort -u
echo
echo "=== Package list x86_64 (unique) ==="
for f in /usr/x86_64-w64-mingw32/bin/*.dll; do
  x86_64-w64-mingw32-objdump -p "$f" 2>/dev/null | grep -q '__emutls' && pacman -Qo "$f" 2>/dev/null
done | awk '{print $5}' | sort -u
```

Add `*-static` packages manually as the script does not find those.

Cherry-pick 852a1754a8ebf6c3929a70e08eaf0aede857c959 to enable native TLS in `mingw-w64-gcc`.

Update the `mingw-w64` core packages to have the most recent fixes available.

Rebuilt the core `mingw-w64` packages (`mingw-w64-gcc` should be rebuilt twice):
```
mingw-w64-gcc
mingw-w64-headers
mingw-w64-crt
mingw-w64-winpthreads
mingw-w64-gcc
```

Rebuilt the previously determined packages, on 2026-09-16 those would be:
```
mingw-w64-abseil-cpp
mingw-w64-assimp
mingw-w64-avisynthplus
mingw-w64-boost
mingw-w64-c++utilities
mingw-w64-cmocka
mingw-w64-coin-or-ipopt
mingw-w64-gklib
mingw-w64-glpk
mingw-w64-glslang
mingw-w64-gnutls
mingw-w64-google-glog
mingw-w64-grpc
mingw-w64-highway
mingw-w64-icu
mingw-w64-jasper
mingw-w64-libjpeg-turbo
mingw-w64-libsodium
mingw-w64-libssh
mingw-w64-llvm
mingw-w64-mariadb-connector-c
mingw-w64-metis
mingw-w64-mpfr
mingw-w64-nlopt
mingw-w64-openal
mingw-w64-opencv
mingw-w64-pixman
mingw-w64-poppler
mingw-w64-protobuf
mingw-w64-qt5-base
mingw-w64-qt5-base-static
mingw-w64-qt6-base
mingw-w64-qt6-base-static
mingw-w64-qt6-declarative
mingw-w64-qt6-declarative-static
mingw-w64-qt6-multimedia
mingw-w64-qt6-multimedia-static
mingw-w64-qt6-quick3d
mingw-w64-qt6-quick3d-static
mingw-w64-qt6-shadertools
mingw-w64-qt6-shadertools-static
mingw-w64-qt6-tasktree
mingw-w64-qt6-tasktree-static
mingw-w64-suitesparse
mingw-w64-syncthingtray
mingw-w64-syncthingtray-qt6
mingw-w64-tbb
mingw-w64-z3
mingw-w64-zimg
```

## Remarks
* `mingw-w64-clang-aarch64-*` package are not affected as they are built with llvm/clang
  as provided by Arch Linux which was never patched to use emutls (as MSYS2 did, see
  https://github.com/msys2/MINGW-packages/pull/29407/changes). So these packages already
  use native TLS.
* Command to check TLS entry: `x86_64-w64-mingw32-objdump -p … | grep -i "Thread Storage"`
    * or: `llvm-readobj --coff-tls-directory …`
* Command to debug with WINE: `winedbg --gdb …`

## Blockers
* Apps using static Qt 6 (using Qt Widgets and otherwise only qtbase modules) crash when
  instantiating `QApplication`:
  ```
  wine: Unhandled page fault on write access to FFFFFFFFFFFFFFF9 at address 0000000141501C11 (thread 0024), starting debugger...
  ```
    * Building Qt with `-DQT_FEATURE_gc_binaries=OFF` to get rid of `-ffunction-sections`,
      `-fdata-sections` and `-Wl,--gc-sections` did not help
    * Building Qt with `-ftls-model=local-exec` did not help (probably does not affect PE
      target)
    * Adding an early return in `destroy_current_thread_data` if `p` is `nullptr` did not
      help
    * Rewriting `set_thread_data` to avoid using `thread_local` did not help (but the
      rewrite might have contained mistakes)
    * Using shared Qt 6 and shared/static Qt 5 work
    * Using `std::thread`/`QThread` in combination with non-trivial `thread_local` objects
      in the code of the statically linked Qt 6 app (before the `QApplication` instantiation)
      works - so the setup is not completely broken
* Whether other libraries (e.g. Boost or gRPC) are also affected still needs to be
  determined

## Links
* Discussion: https://github.com/Martchus/PKGBUILDs/discussions/145#discussioncomment-18274800
* MSYS2 issue: https://github.com/msys2/MINGW-packages/issues/29272
* GCC bug: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=80881
    * search: https://gcc.gnu.org/bugzilla/buglist.cgi?quicksearch=native%20tls
* GCC release note: https://gcc.gnu.org/gcc-16/changes.html#windows
* Other toolchain build scripts:
    * MXE (native TLS disabled, static Qt 6 build scripts present):
        * https://github.com/mxe/mxe/blob/master/src/gcc.mk
        * https://github.com/mxe/mxe/tree/master/src/qt/qt6
    * MSYS2 (native TLS enabled, no static Qt 6 build scripts present):
        * https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-gcc/PKGBUILD
        * https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-binutils/PKGBUILD
        * https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-headers/PKGBUILD
        * https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-crt/PKGBUILD
        * https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-winpthreads/PKGBUILD
        * https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-qt6-base/PKGBUILD
    * Arch Linux (native TLS enabled, only core packages provided):
        * https://archlinux.org/packages?q=mingw-w64
* Other related issues:
    * https://github.com/wxWidgets/wxWidgets/issues/26195
* Additional resources:
    * https://learn.microsoft.com/en-us/windows/win32/dlls/using-thread-local-storage-in-a-dynamic-link-library
    * https://learn.microsoft.com/en-us/windows/win32/procthread/using-thread-local-storage

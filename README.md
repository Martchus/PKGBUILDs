# PKGBUILDs
Contains PKGBUILD files for creating Arch Linux packages. If you would like to improve one of
my AUR packages, just create a PR here.

## Overview of provided packages
* Packages for my own applications and libraries such as
  [Syncthing Tray](https://github.com/Martchus/syncthingtray),
  [Tag Editor](https://github.com/Martchus/tageditor),
  [Password Manager](https://github.com/Martchus/passwordmanager), …
* Packages [I maintain in the AUR](https://aur.archlinux.org/packages/?O=0&SeB=M&K=Martchus&outdated=&SB=v&SO=d&PP=50&do_Search=Go)
  and many more:
    * Misc packages, e.g. Subtitle Composer, OpenELEC DVB firmware and ltunify
    * `mingw-w64-*` packages which allow to build for Windows (i686/x86_64, libstdc++)
      under Arch Linux with GCC, e.g. Boost, Qt 5, Qt 6 and many more
    * `mingw-w64-clang-aarch64-*` packages which allow to build for Windows (aarch64,
      libc++) via LLVM/Clang as provided by Arch Linux, e.g. Boost, Qt 6 and many more
        * These packages are mainly converted on the fly from `mingw-w64-*` packages
          via `devel/conv-variant.pl`.
    * `mingw-w64-aarch64-*` packages which allow to build for Windows (aarch64,
      libstdc++) via GCC, so far no packages provided
        * So far GCC does not support the `aarch64-w64-mingw32` target so no packages have
          been created yet except `mingw-w64-clang-aarch64-binutils` which still needs to be
          renamed to `mingw-w64-aarch64-binutils`.
        * Note that these packages will conflict with `mingw-w64-clang-aarch64-*` packages
          as they share the same install prefix.
    * `static-compat-*` packages containing static libraries to build self-contained
      applications running on older GNU/Linux distributions under Arch Linux, so far the most
      important Qt 6 modules and other important C/C++ libraries are provided
    * `nvidia-580xx` and `nvidia-580xx-lts` packages for building/installing the 580xx version
      of the NVIDIA driver for `linux` and `linux-lts` kernels without having to rely on dkms
      (`nvidia-580xx-dkms` is also provided, though)
    * `android-*` packages which allow to build for Android under Arch Linux using the Android
      SDK, e.g. iconv, Boost, OpenSSL, CppUnit, Qt 6 and Kirigami
    * `wasm-*` packages which allow to build for WebAssembly under Arch Linux using
      the official `emscripten` package; so far limited to a few Qt 6 modules
    * `apple-darwin-*` packages which allow to build for macOS X under Arch
      Linux, e.g. osxcross and Qt 5 (still experimental, more or less discontinued)
* Other packages imported from the AUR to build with slight modifications.

## Binary repository
I also provide a [binary repository](https://martchus.dyn.f3l.de/repo/arch/ownstuff/os)
containing the packages found in this repository and a lot of packages found in
the AUR:

```
[ownstuff-testing]
SigLevel = Optional TrustAll
Server = https://martchus.dyn.f3l.de/repo/arch/$repo/os/$arch
Server = https://ftp.f3l.de/~martchus/$repo/os/$arch

[ownstuff]
SigLevel = Optional TrustAll
Server = https://martchus.dyn.f3l.de/repo/arch/$repo/os/$arch
Server = https://ftp.f3l.de/~martchus/$repo/os/$arch
```

The testing repository is required if you have the official testing repository
enabled. (Packages contained by ownstuff-testing are linked against packages
found in the official testing repository.)

The repository is focusing on x86_64 but some packages are also provided for
i686 and aarch64.

Note that I cannot ensure that required rebuilds always happen fast enough
(since the official developers obviously don't wait for me before releasing their
packages from staging).

Requests regarding binary packages can be tracked on the issue tracker of this
GitHub project as well, e.g. within the [general discussion
issue](https://github.com/Martchus/PKGBUILDs/issues/94).

## Container image, building packages within a container
The directory `devel/container` contains the script `imagebuild` to build a
container image suitable to run Arch Linux's `makepkg` script so you can build
from PKGBUILDs on any environment where Docker, Podman or any other suitable
container runtime is available.

It also contains a script called `makecontainerpkg` which behaves like
`makechrootpkg` from Arch Linux's devtools but uses the previously mentioned
container image. Therefore it does *not* require devtools, a chroot setup and
systemd-nspawn. Instead, any container runtime should be sufficient (tested with
Docker and Podman).

The usage of `makecontainerpkg` is very similar to `makechrootpkg`. Simply run
the script in a directory containing a `PKGBUILD` file. If the directory
contains a file called `pacman.conf` and/or `makepkg.conf` those files are
configured to be used during the build. The call syntax is the following:
```
makecontainerpkg [cre args] --- [makepkg args]
```

Set the environment variable `CRE` to the container runtime executable (by
default `docker`) and set `CRE_IMAGE` to use a different container image.

Note that you can also set the environment variable `TOOL` to invoke a different
tool instead of `makepkg`, e.g. `TOOL=updpkgsums makecontainerpkg` can be used
to update checksums.

Example where the host pacman cache and ccache directories are mounted into the
container and a package rebuild is forced via `makepkg`'s flag `-f`:
```
makecontainerpkg -v /var/cache/pacman/pkg/ -v /run/media/devel/ccache:/ccache -- -f CCACHE_DIR=/ccache
```

Example using podman on a non-Arch system:
```
CRE=podman ../../devel/container/makecontainerpkg -v /hdd/cache/pacman/pkg:/var/cache/pacman/pkg -v /hdd/chroot/remote-config-x86_64:/cfg
```

It still makes sense to specify a cache directory, even though pacman is not
used on the host system. Here also a directory containing a custom `pacman.conf`
and `makepkg.conf` is mounted into the container.

### Podman-specific remarks
To use podman (instead of Docker) simply set `export CRE=podman`.

To be able to run podman without root, you need to ensure user/group IDs can be
mapped. The mapping is configured in the files `/etc/subuid` and `/etc/subgid`.
Use `sudo usermod --add-subuids 200000-265536 --add-subgids 200000-265536 $USER`
to configure it for the current user and verify the configuration via
`grep $USER /etc/sub{u,g}id`. Finally, run `podman system migrate` to apply.

To change storage paths so e.g. containers are stored at a different location,
edit `~/.config/containers/storage.conf` (or `/etc/containers/storage.conf` for
system-wide configuration) to set `runroot` and `graphroot` to different
locations.

### Investigation of build failures
By default, `makecontainerpkg` removes the container in the end. Set `DEBUG=1`
to prevent that. Then one can use e.g. `podman container exec -it … bash` to
enter the container for manual investigation. Set `DEBUG=on-failure` to only
keep the container in case of a failure.

### Using Arch-packages on another distribution via a container
If you want to cross-compile software on non-Arch distributions you can make use
of the `android-*` and `mingw-w64-*` packages provided by this repository using
an Arch Linux container. The container image mentioned before is also suitable
for this purpose.

To build my projects, have a look at
[CMake presets](https://github.com/Martchus/cpp-utilities/blob/master/README.md#remarks-about-building-for-android)
I provide for building on Android.

Otherwise, checkout the following subsections for generic example commands to
build CMake-based projects in a container for Windows and Android. Note that
these commands are intended to be run without root (see section "Podman-specific
remarks" for details). In this case files that are created from within the
container in the build and source directories will have your normal user/group
outside the container which is quite convenient (within the container they will
be owned by root).

#### Setup
Checkout the script under `devel/container/create-devel-container-example` for
example commands.

#### Start interactive shell in container
```
podman container exec -it archlinux-devel-container bash
```

#### Install stuff you want, e.g. Qt packages for targeting mingw-w64 or Android
```
podman container exec -it archlinux-devel-container \
  pacman -Syu ninja git mingw-w64-cmake qt6-{base,tools} mingw-w64-qt6-{base,tools,translations,svg,5compat}
```

```
podman container exec -it archlinux-devel-container \
  pacman -Syu clang ninja git extra-cmake-modules android-cmake qt6-{base,tools,declarative,shadertools} android-aarch64-qt6-{base,declarative,tools,translations,svg,5compat} android-aarch64-{boost,libiconv,qqc2-breeze-style}
```

#### Building for Windows using mingw-w64-* packages
Configure the build, e.g. run CMake:
```
podman container exec -it archlinux-devel-container x86_64-w64-mingw32-cmake \
  -G Ninja \
  -S /src/c++/cmake/PianoBooster \
  -B /build/pianobooster-x86_64-w64-mingw32-release \
  -DPKG_CONFIG_EXECUTABLE:FILEPATH=/usr/bin/x86_64-w64-mingw32-pkg-config \
  -DQT_PACKAGE_NAME:STRING=Qt6
```

Conduct the build, e.g. invoke Ninja build system via CMake:
```
podman container exec -it archlinux-devel-container bash -c '
  source /usr/bin/mingw-env x86_64-w64-mingw32
  cmake --build /build/pianobooster-x86_64-w64-mingw32-release --verbose'
```

#### Building for Android using android-* packages
Use `keytool` to generate a key for signing the APK:
```
podman container exec -it archlinux-devel-container keytool …
```

Configure the build, e.g. run CMake:
```
podman container exec -it archlinux-devel-container bash -c '
  android_arch=aarch64
  export PATH=/usr/lib/jvm/java-17-openjdk/bin:$PATH
  source /usr/bin/android-env $android_arch
  android-$android_arch-cmake \
    -G Ninja \
    -S /src/c++/cmake/subdirs/passwordmanager \
    -B /build/passwordmanager-android-$android_arch-release \
    -DCMAKE_FIND_ROOT_PATH="${ANDROID_PREFIX}" \
    -DANDROID_SDK_ROOT="${ANDROID_HOME}" \
    -DPKG_CONFIG_EXECUTABLE:FILEPATH=/usr/bin/android-$android_arch-pkg-config \
    -DQT_PACKAGE_PREFIX:STRING=Qt6 \
    -DKF_PACKAGE_PREFIX:STRING=KF6'
```

Conduct the build, e.g. invoke Ninja build system via CMake:
```
podman container exec -it archlinux-devel-container bash -c '
  export PATH=/usr/lib/jvm/java-17-openjdk/bin:$PATH
  source /usr/bin/android-env aarch64
  cmake --build /build/passwordmanager-android-aarch64-release --verbose'
```

#### Deploy/debug Android package using tooling from android-sdk package
```
#  example values; ports for pairing and connection are distinct
phone_ip=192.168.178.42 pairing_port=34765 pairing_code=922102 connection_port=32991
podman container exec -it archlinux-devel-container \
  /opt/android-sdk/platform-tools/adb pair "$phone_ip:$pairing_port" "$pairing_code"
podman container exec -it archlinux-devel-container \
  /opt/android-sdk/platform-tools/adb connect "$phone_ip:$connection_port"
podman container exec -it archlinux-devel-container \
  /opt/android-sdk/platform-tools/adb logcat
podman container exec -it archlinux-devel-container \
  /opt/android-sdk/platform-tools/adb install …
```

#### Delete container setup again (when no longer needed)
```
podman container stop archlinux-devel-container
podman container rm archlinux-devel-container
```

### Other approaches
There's also the 3rd party repository
[docker-mingw-qt5](https://github.com/mdimura/docker-mingw-qt5) which contains
an image with many mingw-w64 package pre-installed.

## Structure
Each package is in its own subdirectory:
```
default-pkg-name/variant
```
where `default-pkg-name` is the default package name (e.g. `qt5-base`) and
`variant` usually one of:

* `default`: the regular package
* `git`/`svn`/`hg`: the development version
* `mingw-w64`: the Windows version (i686/dw2 and x86_64/SEH)
* `android-{aarch64,armv7a-eabi,x86-64,x86}`: the Android version (currently
  only aarch64 actively maintained/tested)
* `apple-darwin`: the macOS X version (still experimental)

The repository does not contain `.SRCINFO` files.

---

The subdirectory `devel` contains additional files, mainly for development
purposes. The subdirectory `devel/archive` contains old packages that are no
longer updated (at least not via this repository).

## Generated PKGBUILDs
To avoid repetition some PKGBUILDs are generated. These PKGBUILDs are determined
by the presence of the file `PKGBUILD.sh.ep` besides the actual `PKGBUILD` file.
The `PKGBUILD` file is only present for read-only purposes in this case - do
*not* edit it manually. Instead, edit the `PKGBUILD.sh.ep` file and invoke
`devel/generator/generate.pl`. This requires the `perl-Mojolicious` package to
be installed. Set the environment variable `LOG_LEVEL` to adjust the log level
(e.g. `debug`/`info`/`warn`/`error`). Template layouts/fragments are stored
within `generator/templates`.

### Documentation about the used templating system
* [Syntax](https://mojolicious.org/perldoc/Mojo/Template#SYNTAX)
* [Helpers](https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers)
* [Utilities](https://mojolicious.org/perldoc/Mojo/Util)

## Contributing to patches
Patches for most packages are managed in a fork of the project under my GitHub
profile. For instance, patches for `mingw-w64-qt5-base` are managed at
[github.com/Martchus/qtbase](https://github.com/Martchus/qtbase).

I usually create a dedicated branch for each version, e.g. `5.10.1-mingw-w64`. It
contains all the patches based on Qt 5.10.1. When doing fixes later on, I
usually preserve the original patches and create a new branch, e.g.
`5.10.1-mingw-w64-fixes`.

So in this case it would make sense to contribute directly there. To fix an
existing patch, just create a fixup commit. This (unusual) fixup workflow aims
to keep the number of additional changes as small as possible.

To get the patches into the PKGBUILD files, the script
`devel/qt5/update-patches.sh` is used.

### Mass rebasing of Qt patches
This is always done by me. Please don't try to help here because it will only
cause conflicts. However, the workflow is quite simple:

1. Run `devel/qt5/rebase-patches.sh` on all Qt repository forks or just
   `devel/qt5/rebase-all-patches.sh`
    * e.g. `devel/rebase-patches.sh 5.11.0 5.10.1 mingw-w64-fixes` to create branch
     `5.11.0-mingw-w64` based Qt 5.11.0 using commits from `5.10.1-mingw-w64-fixes`
    * e.g. `devel/qt5/rebase-all-patches.sh 6.9.0-beta3 6.9.0-beta2 '' '' v6.9.0-beta3 v6.9.0-beta2`
      to create `6.9.0-beta3` based on Qt v6.9.0-beta3 using commits from
      `6.9.0-beta2` based on Qt v6.9.0-beta2
    * after fixing possible conflicts, run `devel/qt5/continue-rebase-patches.sh`
    * otherwise, that's it
    * all scripts need to run in the Git repository directory of the Qt module
      except `rebase-all-patches.sh` which needs the environment variable
      `QT_GIT_REPOS_DIR` to be set
2. Run `devel/qt5/update-patches.sh` or `devel/qt5/update-all-patches.sh` to
   update PKGBUILDs
    * e.g. `devel/qt5/update-all-patches.sh '' '' qt6` to update all Qt 6
      packages
    * e.g. `devel/qt5/update-all-patches.sh 6.9.0-beta3-mingw-w64 '' qt6 v6.9.0-beta3`
      to update all Qt 6 packages using a special branch based on a special tag

## Brief documentation about mingw-w64-qt packages
The Qt project does not support building Qt under GNU/Linux when targeting
mingw-w64. With Qt 6 they also stopped 32-bit builds. They also don't provide
static builds targeting mingw-w64. They are also relying a lot on their bundled
libraries while my builds aim to build dependencies separately. So expect some
rough edges when using my packaging.

Nevertheless it makes sense to follow the official documentation. For concrete
examples how to use this packaging with CMake, just checkout the mingw-w64
variants of e.g. `syncthingtray` within this repository. The Arch Wiki also has
a [section about mingw-w64
packaging](https://wiki.archlinux.org/index.php/MinGW_package_guidelines).

Note that the ANGLE and "dynamic" variants of Qt 5 packages do not work because
they would require `fxc.exe` to build.

### Tested build and deployment tools for mingw-w64-qt5 packages
Currently, I test with qmake and CMake. With both build systems it is possible
to use either the shared or the static libraries. Please read the comments in
the PKGBUILD file itself and the pinned comments in [the
AUR](https://aur.archlinux.org/packages/mingw-w64-qt5-base) for further
information.

There are also pkg-config files, but those aren't really tested.

`qbs` and `windeployqt` currently don't work very well (see issues). Using the
static libraries or mxedeployqt might be an alternative to windeployqt.

### Tested build and deployment tools for mingw-w64-qt6 packages
In order to build a Qt-based project using mingw-w64-qt6 packages one also needs
to install the regular `qt6-base` package for development tools such as `moc`.
The packages `qt6-tools`, `qt6-declarative` and `qt6-shadertools` also
contain native binaries which might be required by some projects. At this point the
setup can break if the version of regular packages and the versions of the
mingw-w64 packages differ. I cannot do anything about it except trying to
upgrade the mingw-w64 packages as fast as possible. There's actually a lengthy
discussion about this topic on the
[Qt development mailing list](https://lists.qt-project.org/pipermail/development/2021-September/041732.html)
so the situation might improve in the future. Note that as of
qtbase commit `5ffc744b791a114a3180a425dd26e298f7399955` (requires Qt > 6.2.1)
one can specify `-DQT_NO_PACKAGE_VERSION_CHECK=TRUE` to ignore the strict
versioning check.

Currently, I only test CMake. It is possible to use either the shared or the
static libraries. The static libraries are installed into a nested prefix
(`/usr/i686-w64-mingw32/static` and `/usr/x86_64-w64-mingw32/static`) so this
prefix needs to be prepended to `CMAKE_FIND_ROOT_PATH` for using the static
libraries. To generally prefer static libraries one might use the helper scripts
provided by the `mingw-w64-cmake-static` package.

The build systems qbs and qmake are not tested. It looks like Qt's build system
does not install pkg-config files anymore and so far no effort has been taken to
enable them.

Note that windeployqt needed to be enabled by the official/regular `qt6-tools`
package but would likely not work very well anyways. Using the static libraries
or mxedeployqt might be an alternative for windeployqt.

### Static plugins and CMake
Qt 5 initially didn't support it so I added patches to make it work. After Qt 5
added support I still kept my own version because I didn't want to risk any
regressions (which would be tedious to deal with). So the [official
documentation](https://doc.qt.io/qt-5/qtcore-cmake-qt-import-plugins.html) does
**not** apply to my packages. One simply has to link against the targets of the
wanted static plugins manually.

However, for Qt 6 I dropped my patches and the official documentation applies. I
would still recommend to set the target property `QT_DEFAULT_PLUGINS` of
relevant targets to `0` and link against wanted plugin targets manually. At
least in my cases the list of plugins selected by default seemed needlessly
long. I would also recommend to set the CMake variable
`QT_SKIP_AUTO_QML_PLUGIN_INCLUSION` to a false value because this pulls in a lot
of dependencies which are likely not needed.

### Further documentation
The directory `qt5-base/mingw-w64` also contains a README with more Qt 5
specific information.

## Running Windows executables built using mingw-w64 packages with WINE
It is recommended to use the scripts `x86_64-w64-mingw32-wine` and
`i686-w64-mingw32-wine` provided by the `mingw-w64-wine` package. These scripts
are a wrapper around the regular `wine` binary ensuring all the DLLs provided by
`mingw-w64-*`-packages of the relevant architecture can be located. It also uses
a distinct `wine` prefix so your usual configuration (e.g. tailored to run
certain games) does not get in the way and is also not messed with.

Here are nevertheless some useful hints to run WINE manually:

* Set the environment variable `WINEPREFIX` to use a distinct WINE-prefix if
  wanted.
* Set `WINEPATH` for the search directories of needed DLLs, e.g.
  `WINEPATH=$builds/libfoo;$builds/libbar;/usr/x86_64-w64-mingw32`.
* Set `WINEARCH` to `win32` for a 32-bit environment (`win64` is the default
  which will get you a 64-bit environment)
* Set `WINEDLLOVERRIDES` to control loading DLLs, e.g.
  `WINEDLLOVERRIDES=mscoree,mshtml=` disables the annoying Gecko popup.
* To set environment variables like `PATH` or `QT_PLUGIN_PATH` for the Windows
  program itself use the following approach:
    1. Open `regedit`
    2. Go to `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment`
    3. Add/modify the variable, e.g. set
       `PATH=C:\windows\system32;C:\windows;Z:\usr\x86_64-w64-mingw32\bin` and
       `QT_PLUGIN_PATH=Z:/usr/x86_64-w64-mingw32/lib/qt6/plugins`
* It is possible to run apps in a headless environment but be aware that WINE
  is not designed for this. For instance, when an application crashes WINE
  still attempts to show the crash window and the application stays stuck in
  that state.
* See https://wiki.winehq.org/Wine_User's_Guide for more information

### Running aarch64 binaries compiled via mingw-w64-clang-aarch64 packages
It is possible to run aarch64 binaries on an x86_64 host using WINE and QEMU,
checkout [the Linaro blog](https://www.linaro.org/blog/emulate-windows-on-arm)
for details. They also provide a container image that is easy to use:

```
source mingw-clang-env aarch64-w64-mingw32
$CXX $CXXFLAGS -mconsole -static main.cpp -o main.exe
podman run -it --rm -v "$PWD:/pwd" linaro/wine-arm64 wine-arm64 /pwd/main.exe
```

You can also use this approach to test graphical applications, e.g.:
```
xhost +local:
podman run -it -e DISPLAY -v ~/.Xauthority:/root/.Xauthority:Z --ipc=host --net=host --rm -v "$PWD:/pwd" linaro/wine-arm64 wine-arm64 /pwd/syncthingtray.exe --windowed
```

## Static GNU/Linux libraries
This repository contains several `static-compat-*` packages providing static
libraries intended to distribute "self-contained" executables. These libraries
are built against an older version of glibc to be able to run on older
distributions without having to link against glibc statically. The resulting
binaries should run on distributions with glibc 2.26 or newer (or Linux 4.4 and
newer when linking against glibc statically), e.g. openSUSE Leap 15.0, Fedora
27, Debian 10 and Ubuntu 18.04. The packages might not be updated as regularly
as their normal counterparts but the idea is to provide an environment with a
recent version of GCC/libstdc++ and other libraries such as Qt and Boost but
still be able to run the resulting executables on older distributions.

To use the packages, simply invoke `/usr/static-compat/bin/g++` instead of
`/usr/bin/g++`. The package `static-compat-environment` provides a script to set
a few environment variables to make this easier. There are also packages
providing build system wrappers such as `static-compat-cmake`.

It would be conceivable to make fully statically linked executables. However, it
would not be possible to support OpenGL because glvnd and vendor provided OpenGL
libraries are always dynamic libraries. It also makes no sense to link against
glibc (and possibly other core libraries) statically as they might use `dlopen`.
Therefore this setup aims for a partially statically linked build instead, where
stable core libraries like glibc/pthreads/OpenGL/… are assumed to be provided by
the GNU/Linux system but other libraries like libstdc++, Boost and Qt are linked
against statically. This is similar to AppImage where a lot of libraries are
bundled but certain core libraries are expected to be provided by the system.

Examples for resulting binaries can be found in the release sections of my
projects [Tag Editor](https://github.com/Martchus/tageditor/releases) and
[Syncthing Tray](https://github.com/Martchus/syncthingtray/releases). Those are
Qt 6 applications and the resulting binaries run on the mentioned platforms
supporting X11 and Wayland natively.

Note that I decided to let static libraries live within the subprefix
`/usr/static-compat` (in contrast to `-static` packages found in the AUR). The
main reason is that my packaging requires a custom glibc/GCC build for
compatibility and I suppose that simply needs to live within its own prefix.
Besides, the version might not be kept 100 % in sync with the shared
counterpart. Hence it makes sense to make the static packages independent with
their own headers and configuration files to avoid problems due to mismatching
versions. Additionally, some projects (such as Qt) do not support installing
shared and static libraries within the same prefix at the same time because the
config files would clash.

### Testing executables built with static-compat packages
This can be done using a VM or a container. An image for a suitable test
container can be found in this repository and used like this:

```
podman image build devel/container/ubuntu --tag static-compat-test-env
podman run --rm -e DISPLAY -v ~/.Xauthority:/root/.Xauthority:Z --ipc=host --net=host \
           -v "$PWD:/opt/bin" -it static-compat-test-env /opt/bin/syncthingtray
```

## Copyright notice and license
Copyright © 2015-2026 Marius Kittler

All code is licensed under [GPL-2.0-or-later](LICENSE).

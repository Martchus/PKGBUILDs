# PKGBUILDs
Contains PKGBUILD files for creating Arch Linux packages:

* Packages for my own applications and libraries such as [Syncthing Tray](https://github.com/Martchus/syncthingtray),
  [Tag Editor](https://github.com/Martchus/tageditor), [Password Manager](https://github.com/Martchus/passwordmanager), ...
* Packages [I maintain in the AUR](https://aur.archlinux.org/packages/?O=0&SeB=M&K=Martchus&outdated=&SB=v&SO=d&PP=50&do_Search=Go):
    * misc packages, eg. Subtitle Composer, openelec-dvb-firmware, Jangouts
    * mingw-w64 packages which allow to build for Windows under Arch Linux, eg. FreeType 2, Qt 5 and Qt 6
    * android packages which allow to build for Android under Arch Linux, eg. iconv, Boost, OpenSSL, CppUnit, Qt 5 and Kirigami
    * apple-darwin packages which allow to build for MaxOS X under Arch Linux, eg. osxcross and Qt 5 (still experimental)
* Other packages imported from the AUR to build with slight modifications

So if you like to improve one of my AUR packages, just create a PR here.

## Binary repository
I also provide a [binary repository](https://martchus.no-ip.biz/repo/arch/ownstuff/os) containing the packages found
in this repository and a lot of packages found in the AUR:

```
[ownstuff-testing]
SigLevel = Optional TrustAll
Server = https://martchus.no-ip.biz/repo/arch/$repo/os/$arch
Server = https://ftp.f3l.de/~martchus/$repo/os/$arch

[ownstuff]
SigLevel = Optional TrustAll
Server = https://martchus.no-ip.biz/repo/arch/$repo/os/$arch
Server = https://ftp.f3l.de/~martchus/$repo/os/$arch
```

The testing repository is required if you have the official testing repository enabled. (Packages contained by ownstuff-testing
are linked against packages found in the official testing repository.)

The repository is focusing on x86_64 but some packages are also provided for i686 and aarch64.

Note that I can not assure that required rebuilds always happen fast enough (since the offical developers obviously don't wait for
me before releasing their packages from staging).

Requests regarding binary packages can be tracked on the issue tracker of this GitHub project as well, e.g. within the
[general discussion issue](https://github.com/Martchus/PKGBUILDs/issues/94).

## Docker image
Checkout the repository [docker-mingw-qt5](https://github.com/mdimura/docker-mingw-qt5).

## Structure
Each package is in its own subdirectoy:
```
default-pkg-name/variant
```
where `default-pkg-name` is the default package name (eg. `qt5-base`) and `variant` usually one of:

* `default`: the regular package
* `git`/`svn`/`hg`: the development version
* `mingw-w64`: the Windows version (i686/SJLJ and x86_64/SEH)
* `android-{aarch64,armv7a-eabi,x86-64,x86}`: the Android version (currently only aarch64 actively maintained/tested)
* `apple-darwin`: the MacOS X version (still experimental)

The repository does not contain `.SRCINFO` files.

## Generated PKGBUILDs
To avoid repetition some PKGBUILDs are generated. These PKGBUILDs are determined by the presence of the file
`PKGBUILD.sh.ep` besides the actual `PKGBUILD` file. The `PKGBUILD` file is only present for read-only purposes in
this case - do *not* edit it manually. Instead, edit the `PKGBUILD.sh.ep` file and invoke `devel/generator/generate.pl`.
This requires the `perl-Mojolicious` package to be installed. Set the environment variable `LOG_LEVEL` to adjust the
log level (e.g. `debug`/`info`/`warn`/`error`). Template layouts/fragments are stored within `generator/templates`.

### Documentation about the used templating system
* [Syntax](https://mojolicious.org/perldoc/Mojo/Template#SYNTAX)
* [Helper](https://mojolicious.org/perldoc/Mojolicious/Plugin/DefaultHelpers)
* [Utilities](https://mojolicious.org/perldoc/Mojo/Util)

## Contributing to patches
Patches for most packages are managed in a fork of the project under my GitHub profile. For instance,
patches for `mingw-w64-qt5-base` are managed at [github.com/Martchus/qtbase](https://github.com/Martchus/qtbase).

I usually create a dedicated branch for each version, eg. `5.10.1-mingw-w64`. It contains all the patches based on
Qt 5.10.1. When doing fixes later on, I usually preserve the original patches and create a new branch, eg.
`5.10.1-mingw-w64-fixes`.

So in this case it would make sense to contribute directly there. To fix an existing patch, just create a fixup commit.
This (unusual) fixup workflow aims to keep the number of additional changes as small as possbile.

To get the patches into the PKGBUILD files, the script `devel/qt5/update-patches.sh` is used.

### Mass rebasing of Qt patches
This is always done by me. Please don't try to help here because it will only cause conflicts. However, the
workflow is quite simple:

1. Run `devel/qt5/rebase-patches.sh` on all Qt repository forks or just `devel/qt5/rebase-all-patches.sh`
    * eg. `rebase-patches.sh 5.11.0 5.10.1 fixes` to create branch `5.11.0-mingw-w64` based on `5.10.1-mingw-w64-fixes`
    * after fixing possible conflicts, run `devel/qt5/continue-rebase-patches.sh`
    * otherwise, that's it
    * all scripts need to run in the Git repository directory of the Qt module except `rebase-all-patches.sh` which needs
      the environment variable `QT_GIT_REPOS_DIR` to be set
2. Run `devel/qt5/update-patches.sh` or `devel/qt5/update-all-patches.sh` to update PKGBUILDs

## Brief documentation about mingw-w64-qt packages
The Qt project does not support building Qt under GNU/Linux when targeting Windows. With Qt 6 they also stopped 32-bit
builds. They also don't provide static builds for Windows. They are also relying a lot on their bundled libraries while
my builds aim to build dependencies separately. So expect some rough edges when using my packaging.

Neverthless it make sense to follow the official documentation. For concrete examples how to use this packaging with
CMake, just checkout the mingw-w64 variants of e.g. `syncthingtray` within this repository. The Arch Wiki also has
a [section about mingw-w64 packaging](https://wiki.archlinux.org/index.php/MinGW_package_guidelines).

### Tested build and deployment tools for mingw-w64-qt5 packages
Currently, I test with qmake and CMake. With both build systems it is possible to use either the shared or the
static libraries. Please read the comments in the PKGBUILD file itself and the pinned comments in
[the AUR](https://aur.archlinux.org/packages/mingw-w64-qt5-base) for futher information.

There are also pkg-config files, but those aren't really tested.

qbs and windeployqt currently don't work very well (see issues). Using the static libraries or mxedeployqt might be an
alternative for windeployqt.

### Tested build and deployment tools for mingw-w64-qt6 packages
In order to build a Qt-based project using mingw-w64-qt6 packages one also needs to install the regular `qt6-base` package
for development tools such as moc. The packages `qt6-tools` and `qt6-declarative` contain also native packages which might
be required by some projects.

Currently, I test only CMake. It is possible to use either the shared or the static libraries. The static libraries
are installed into a nested prefix (`/usr/i686-w64-mingw32/static` and `/usr/x86_64-w64-mingw32/static`) so this prefix
needs to be prepended to `CMAKE_FIND_ROOT_PATH` for using the static libraries. To generally prefer static libraries
one might use the helper scripts provided by the `mingw-w64-cmake-static` package.

The build systems qbs and qmake are not tested. It looks like Qt's build system does not install pkg-config files
anymore and so far no effort has been taken to enable them.

Note that windeployqt needed to be enabled by the official/regular `qt6-tools` package but would likely not work very
well anyways. Using the static libraries or mxdeployqt might be an alternative for windeployqt.


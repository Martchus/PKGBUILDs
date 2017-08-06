# PKGBUILDs
Contains PKGBUILD files for creating Arch Linux packages:

* Packages for my own applications and libraries such as [Syncthing Tray](https://github.com/Martchus/syncthingtray),
  [Tag Editor](https://github.com/Martchus/tageditor), [Password Manager](https://github.com/Martchus/passwordmanager), ...
* Packages [I maintain in the AUR](https://aur.archlinux.org/packages/?O=0&SeB=M&K=Martchus&outdated=&SB=v&SO=d&PP=50&do_Search=Go):
    * misc packages, eg. Gogs/Gitea, Subtitle Composer, openelec-dvb-firmware
    * mingw-w64 packages which allow to build for Windows under Arch Linux, eg. freetype2 and Qt 5
    * apple-darwin packages which allow to build for MaxOS X under Arch Linux, eg. osxcross and Qt 5
* Other packages imported from the AUR to build with slight modifications

So if you like to improve one of my AUR packages, just create a PR here.

## Structure
Each package is in its own subdirectoy:
```
default-pkg-name/variant
```
where `default-pkg-name` is the of the default package name (eg. `qt5-base`) and `variant` usually one of:

* `default`: the regular package
* `git`/`svn`/`hg`: the development version
* `mingw-w64`: the Windows version
* `apple-darwin`: the MacOS X version

The repository does not contain `.SRCINFO` files.

## Binary repository
I also provide a [binary repository](https://martchus.no-ip.biz/repo/arch/ownstuff/os) containing the packages found
in this repository and a lot of packages found in the AUR.

For more information visit my [website](https://martchus.no-ip.biz/website/page.php?name=programming).

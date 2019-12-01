# Maintainer: Martchus <martchus@gmx.net>

# All my PKGBUILDs are managed at https://github.com/Martchus/PKGBUILDs where
# you also find the URL of a binary repository.

pkgname=qpaeq-menu-entry
_execname=qpaeq
pkgver=1.0.0
pkgrel=5
arch=('any')
pkgdesc='Menu entry for qpaeq - a PulseAudio equalizer frontend'
license=('BSD')
depends=('pulseaudio-equalizer')
install="${_execname}.install"
url=
source=("$_execname.desktop" "$_execname.svg")
md5sums=('f4d3cf3875c0ee022bf5a797f76f6652'
         '82df9349be90add6be1be8c537f4abef')

package() {
  cd "$srcdir"
  install -m644 -D "./${_execname}.svg" "$pkgdir/usr/share/icons/hicolor/scalable/apps/${_execname}.svg"
  install -m644 -D "./${_execname}.desktop" "$pkgdir/usr/share/applications/${_execname}.desktop"
}

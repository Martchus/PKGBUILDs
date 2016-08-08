# Maintainer: Martchus <martchus@gmx.net>

# All my PKGBUILDs are managed at https://github.com/Martchus/PKGBUILDs where
# you also find the URL of a binary repository.

pkgname=qpaeq-menu-entry
_execname=qpaeq
pkgver=1.0.0
pkgrel=4
arch=('any')
pkgdesc='Menu entry for qpaeq - a PulseAudio equalizer frontend'
license=('BSD')
depends=('pulseaudio-equalizer' 'python-pyqt4')
makedepends=
install="${_execname}.install"
url=
source=("$_execname.desktop" "$_execname.svg")
md5sums=('2bb4b813d1007bd93b58c15f1334fe88'
         '82df9349be90add6be1be8c537f4abef')

package() {
  cd "$srcdir"
  install -m644 -D "./${_execname}.svg" "$pkgdir/usr/share/icons/hicolor/scalable/apps/${_execname}.svg"
  install -m644 -D "./${_execname}.desktop" "$pkgdir/usr/share/applications/${_execname}.desktop"
}

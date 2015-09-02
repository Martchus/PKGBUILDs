# Maintainer: Arthur Țițeică /arthur.titeica/gmail/com
# Contributor: Jonas Heinrich <onny@project-insanity.org>

pkgname=subtitlecomposer-git
pkgver=v0.5.6.2.g6528219
pkgrel=1
pkgdesc="A KDE subtitle editor"
arch=('i686' 'x86_64')
url="https://github.com/maxrd2/subtitlecomposer"
license=('GPL')
depends=('kdelibs' 'gettext')
makedepends=('cmake' 'automoc4' 'git')
optdepends=("mplayer: for MPlayer backend")
source=('git+https://github.com/maxrd2/subtitlecomposer.git')
md5sums=('SKIP')

pkgver() {
  cd "subtitlecomposer"
  git describe --always | sed 's|-|.|g'
}

build() {
  cd "subtitlecomposer"
  cmake -DCMAKE_INSTALL_PREFIX=/usr
  make
}

package() {
  cd "subtitlecomposer"
  make DESTDIR=${pkgdir} install
}

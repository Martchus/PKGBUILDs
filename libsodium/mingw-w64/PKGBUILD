# Maintainer: Wolfgang Pupp <wolfgang.pupp@gmail.com>
# Maintainer: Martchus <martchus@gmx.net>
# Contributor: Felix Yan <felixonmars@archlinux.org>
# Contributor: namelessjon <jonathan.stott@gmail.com>
# Contributor: Alessio Sergi <asergi at archlinux dot us>
# Contributor: Alexey Pavlov <alexpux@gmail.com>

_realname=libsodium
pkgname="mingw-w64-${_realname}"
pkgver=1.0.20
pkgrel=2
pkgdesc="A modern, portable, easy to use crypto library (mingw-w64)"
arch=(any)
url="https://github.com/jedisct1/libsodium"
license=('custom:ISC')
depends=('mingw-w64-crt')
options=(!strip !buildflags staticlibs)
makedepends=('mingw-w64-configure')
source=(https://download.libsodium.org/libsodium/releases/${_realname}-${pkgver}.tar.gz{,.sig})
b2sums=('2f1d8b2dc8a65f95433132b12bdccb7e0e4750326b05c4f42ddd3a74bf568faa2515384bfe94bba2ef420aff35c515d3d44945ea5a68f72e6a73b3a9b5bb234c'
        'SKIP')

validpgpkeys=("54A2B8892CC3D6A597B92B6C210627AABA709FE1") # Frank Denis
_architectures="i686-w64-mingw32 x86_64-w64-mingw32"

build() {
  for _arch in ${_architectures}; do
    mkdir -p "${srcdir}"/build-${_arch} && cd "${srcdir}"/build-${_arch}

    ${_arch}-configure ../${_realname}-${pkgver}

    make
  done
}

package() {
  for _arch in ${_architectures}; do
    cd "${srcdir}"/build-${_arch}
    make DESTDIR="$pkgdir" install

    ${_arch}-strip --strip-unneeded "${pkgdir}"/usr/${_arch}/bin/*.dll
    ${_arch}-strip -g "${pkgdir}"/usr/${_arch}/lib/*.a

    rm "${pkgdir}/usr/${_arch}/bin/"*.def
    rm -rf "${pkgdir}/usr/${_arch}/share"
  done

  install -Dm644 ${srcdir}/${_realname}-${pkgver}/LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}


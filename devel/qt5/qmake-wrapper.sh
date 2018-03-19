#!/usr/bin/bash
# allows to play with qmake settings without recompiling it
if [[ $1 == '-query' ]]; then
    echo 'QT_SYSROOT:
QT_INSTALL_PREFIX:/usr/x86_64-w64-mingw32
QT_INSTALL_ARCHDATA:/usr/x86_64-w64-mingw32/lib/qt
QT_INSTALL_DATA:/usr/x86_64-w64-mingw32/share/qt
QT_INSTALL_DOCS:/usr/x86_64-w64-mingw32/share/doc/qt
QT_INSTALL_HEADERS:/usr/x86_64-w64-mingw32/include/qt
QT_INSTALL_LIBS:/usr/x86_64-w64-mingw32/lib
QT_INSTALL_LIBEXECS:/usr/x86_64-w64-mingw32/lib/qt/bin
QT_INSTALL_BINS:/usr/x86_64-w64-mingw32/bin
QT_INSTALL_TESTS:/usr/x86_64-w64-mingw32/tests
QT_INSTALL_PLUGINS:/usr/x86_64-w64-mingw32/lib/qt/plugins
QT_INSTALL_IMPORTS:/usr/x86_64-w64-mingw32/lib/qt/imports
QT_INSTALL_QML:/usr/x86_64-w64-mingw32/lib/qt/qml
QT_INSTALL_TRANSLATIONS:/usr/x86_64-w64-mingw32/share/qt/translations
QT_INSTALL_CONFIGURATION:/usr/x86_64-w64-mingw32/etc
QT_INSTALL_EXAMPLES:/usr/x86_64-w64-mingw32/share/qt/examples
QT_INSTALL_DEMOS:/usr/x86_64-w64-mingw32/share/qt/examples
QT_HOST_PREFIX:/usr/x86_64-w64-mingw32
QT_HOST_DATA:/usr/x86_64-w64-mingw32/lib/qt
QT_HOST_BINS:/usr/x86_64-w64-mingw32/lib/qt/bin
QT_HOST_LIBS:/usr/x86_64-w64-mingw32/lib
QMAKE_SPEC:linux-g++
QMAKE_XSPEC:win32-g++
QMAKE_VERSION:3.1
QT_VERSION:5.10.1'
    exit 0
fi

/usr/bin/x86_64-w64-mingw32-qmake-qt5 "$@"

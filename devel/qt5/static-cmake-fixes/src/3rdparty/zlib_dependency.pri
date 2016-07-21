# zlib dependency satisfied by bundled 3rd party zlib or system zlib
contains(QT_CONFIG, system-zlib) {
    unix|mingw {
        contains(QT_CONFIG, static): LIBS_PRIVATE += -Bstatic -lz -Wl,-Bdynamic
        else: LIBS_PRIVATE += -lz
    } else {
        isEmpty(ZLIB_LIBS): LIBS += zdll.lib
        else: LIBS += $$ZLIB_LIBS
    }
} else {
    INCLUDEPATH +=  $$PWD/zlib
    !no_core_dep {
        CONFIG += qt
        QT_PRIVATE += core
    }
}

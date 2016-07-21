pcre {
    win32: DEFINES += PCRE_STATIC
    INCLUDEPATH += $$PWD/pcre
    LIBS_PRIVATE += -L$$QT_BUILD_TREE/lib -lqtpcre$$qtPlatformTargetSuffix()
} else {
    contains(QT_CONFIG, static): LIBS_PRIVATE += -Bstatic -lpcre16 -Wl,-Bdynamic
    else: LIBS_PRIVATE += -lpcre16
}

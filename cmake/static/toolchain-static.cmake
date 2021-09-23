# This toolchain file helps building a mostly statically linked executable by
# defining certain variables. It is mainly focusing on dependencies used by Qt.

# prefer libraries from "static" sub-prefix
set(CMAKE_FIND_ROOT_PATH "/usr/static;${CMAKE_FIND_ROOT_PATH}")

# prefer static libraries
# note: It is of no use to set the real variable CMAKE_FIND_LIBRARY_SUFFIXES
#       here because it gets overridden by CMake after loading the toolchain
#       file. The project needs to make the actual override if enforcing static
#       libraries is required.
set(CMAKE_FIND_LIBRARY_SUFFIXES_OVERRIDE ".a;.so")
set(CMAKE_EXE_LINKER_FLAGS "$ENV{LDFLAGS} -static-libgcc -static-libstdc++" CACHE STRING "linker flags for static builds" FORCE)
set(CMAKE_C_FLAGS "$ENV{CFLAGS} -include /usr/static/include/glibc-2.17.h" CACHE STRING "C flags for static builds" FORCE)
set(CMAKE_CPP_FLAGS "$ENV{CPPFLAGS} -include /usr/static/include/glibc-2.17.h" CACHE STRING "Cpp flags for static builds" FORCE)
set(CMAKE_CXX_FLAGS "$ENV{CXXFLAGS} -include /usr/static/include/glibc-2.17.h" CACHE STRING "C++ flags for static builds" FORCE)
set(OPENSSL_USE_STATIC_LIBS ON)
set(BOOST_USE_STATIC_LIBS ON)

# workaround limitations in upstream pkg-config files and CMake find modules
set(pkgcfg_lib_libbrotlicommon_brotlicommon "/usr/lib/libbrotlicommon-static.a" CACHE INTERNAL "static libbrotlicommon")
set(pkgcfg_lib_libbrotlienc_brotlienc "/usr/lib/libbrotlienc-static.a;/usr/lib/libbrotlicommon-static.a" CACHE INTERNAL "static libbrotliend")
set(pkgcfg_lib_libbrotlidec_brotlidec "/usr/lib/libbrotlidec-static.a;/usr/lib/libbrotlicommon-static.a" CACHE INTERNAL "static libbrotlidec")
set(libbrotlicommon_STATIC_LDFLAGS "${pkgcfg_lib_libbrotlicommon_brotlicommon}" CACHE INTERNAL "static libbrotlicommon")
set(libbrotlienc_STATIC_LDFLAGS "${pkgcfg_lib_libbrotlienc_brotlienc}" CACHE INTERNAL "static libbrotliend")
set(libbrotlidec_STATIC_LDFLAGS "${pkgcfg_lib_libbrotlidec_brotlidec}" CACHE INTERNAL "static libbrotlidec")

# define dependencies of various static libraries as CMake doesn't pull them
# reliably automatically
# note: It would be possible to deduce the dependencies via pkg-config. However,
# for simplicity I'm hard-coding the dependencies for now. In some cases the
# pkg-config file wouldn't work anyways because it is only covering the shared
# version (despite use of `-static`).
set(OPENSSL_DEPENDENCIES "-ldl;-pthread" CACHE INTERNAL "dependencies of static OpenSSL libraries")
set(LIBPNG_DEPENDENCIES "-lz" CACHE INTERNAL "dependencies of static libpng")
set(GLIB2_DEPENDENCIES "-pthread" CACHE INTERNAL "dependencies of static Glib2")
set(FREETYPE_DEPENDENCIES "-lbz2;-lharfbuzz;-lfreetype;-lbrotlidec-static;-lbrotlicommon-static" CACHE INTERNAL "dependencies of static FreeType2 library")
set(HARFBUZZ_DEPENDENCIES "-lglib-2.0;${GLIB2_DEPENDENCIES};-lm;-lfreetype;-lgraphite2" CACHE INTERNAL "dependencies of static HarfBuzz library")
set(DBUS1_DEPENDENCIES "-pthread" CACHE INTERNAL "dependencies of static D-Bus1 library")

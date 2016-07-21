f=qt5-allow-usage-of-static-qt-with-cmake.patch
diff -Naur mkspecs/features/data/cmake/Qt5BasicConfig.cmake.in{.orig,} > $f
diff -Naur mkspecs/features/create_cmake.prf{.orig,} >> $f
cat qt5-generate-libs-in-prl-for-cmake.patch >> $f

f=qt5-customize-extensions-for-static-build.patch
diff -Naur mkspecs/features/spec_pre.prf{.orig,} > $f

f=qt5-enforce-static-linkage-of-3rdparty-libs.patch
echo -n > $f
for pri in src/3rdparty/*.pri; do
    diff -Naur $pri{.orig,} >> $f
done

f=qt5-use-pkgconfig-for-harfbuzz.patch
diff -Naur src/3rdparty/harfbuzz_dependency.pri{.orig,} > $f

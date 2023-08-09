set (CMAKE_SYSTEM_NAME Linux)
set (CMAKE_SYSTEM_PROCESSOR @PROCESSOR@)

# specify the cross compiler
set (CMAKE_C_COMPILER @PREFIX@/bin/gcc)
set (CMAKE_CXX_COMPILER @PREFIX@/bin/g++)

# specify the root path of the target environment
set (CMAKE_FIND_ROOT_PATH @PREFIX@)
set (CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
set (CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set (CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set (CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# disable use of find modules that don't work for static libraries
set(CMAKE_DISABLE_FIND_PACKAGE_harfbuzz TRUE)


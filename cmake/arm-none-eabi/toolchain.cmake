set (CMAKE_SYSTEM_NAME Generic)

# specify the cross compiler
set (CMAKE_C_COMPILER @TRIPLE@-gcc)
set (CMAKE_CXX_COMPILER @TRIPLE@-g++)
set (CMAKE_AR:FILEPATH @TRIPLE@-ar)
set (CMAKE_RANLIB:FILEPATH @TRIPLE@-ranlib)

# where is the target environment
set (CMAKE_FIND_ROOT_PATH /usr/@TRIPLE@)

# search for programs in the build host directories
set (CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# for libraries and headers in the target directories
set (CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set (CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set (CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)



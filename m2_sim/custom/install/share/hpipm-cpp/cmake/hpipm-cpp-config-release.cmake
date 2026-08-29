#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "hpipm-cpp::hpipm-cpp" for configuration "Release"
set_property(TARGET hpipm-cpp::hpipm-cpp APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(hpipm-cpp::hpipm-cpp PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libhpipm-cpp.so"
  IMPORTED_SONAME_RELEASE "libhpipm-cpp.so"
  )

list(APPEND _IMPORT_CHECK_TARGETS hpipm-cpp::hpipm-cpp )
list(APPEND _IMPORT_CHECK_FILES_FOR_hpipm-cpp::hpipm-cpp "${_IMPORT_PREFIX}/lib/libhpipm-cpp.so" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)

# This module looks for environment variables detailing where NEMSIO lib is
# If variables are not set, NEMSIO will be built from external source 
include(ExternalProject)
if((NOT BUILD_NEMSIO ) AND (DEFINED ENV{NEMSIO_LIB}))
    set(NEMSIO_LIBRARY $ENV{NEMSIO_LIB} )
    set(NEMSIOINC $ENV{NEMSIO_INC} )
    if( CORE_LIBRARIES )
      list( APPEND CORE_LIBRARIES ${NEMSIO_LIBRARY} )
      list( APPEND CORE_INCS ${NEMSIOINC} )
    else()
      set( CORE_LIBRARIES ${NEMSIO_LIBRARY} )
      set( CORE_INCS ${NEMSIOINC} )
    endif()
else()
  set(CMAKE_INSTALL_PREFIX ${PROJECT_BINARY_DIR})
  ExternalProject_Add(NCEPLIBS-nemsio 
    PREFIX ${PROJECT_BINARY_DIR}/NCEPLIBS-nemsio
    CMAKE_ARGS
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_Fortran_COMPILER=${CMAKE_Fortran_COMPILER}
      -DCMAKE_BUILD_TYPE=RELEASE
    SOURCE_DIR ${PROJECT_SOURCE_DIR}/libsrc/nemsio 
    INSTALL_DIR ${CMAKE_INSTALL_PREFIX}
    BUILD_COMMAND make
    INSTALL_COMMAND make install
  )
  execute_process(COMMAND grep "set(VERSION" CMakeLists.txt WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/libsrc/nemsio OUTPUT_VARIABLE LIBVERSION)
  string(REPLACE "set(VERSION " "" LIBVERSION ${LIBVERSION})
  string(REPLACE ")" "" LIBVERSION ${LIBVERSION})
  string(REPLACE "\n" "" LIBVERSION ${LIBVERSION})
  message("nemsio version is ${LIBVERSION}")
  set( NEMSIO_LIBRARY ${PROJECT_BINARY_DIR}/lib/libnemsio_${LIBVERSION}.a )
  set( NEMSIOINC ${PROJECT_BINARY_DIR}/include )
  if( CORE_BUILT )
      list( APPEND CORE_BUILT ${NEMSIO_LIBRARY} )
      list( APPEND EXT_BUILT NCEPLIBS-nemsio)
  else()
      set( CORE_BUILT ${NEMSIO_LIBRARY} )
      set( EXT_BUILT NCEPLIBS-nemsio)
  endif()
endif( )

set( NEMSIO_LIBRARY_PATH ${NEMSIO_LIBRARY} CACHE STRING "NEMSIO Library Location" )
set( NEMSIO_INCLUDE_PATH ${NEMSIOINC} CACHE STRING "NEMSIO Include Location" )


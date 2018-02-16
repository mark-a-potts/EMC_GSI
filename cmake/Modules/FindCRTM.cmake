# This module defines
#  CORE_INCS
#    List of include file paths for all required modules for GSI
#  CORE_LIBRARIES
#    Full list of libraries required to link GSI executable
include(findHelpers)
if(DEFINED ENV{CRTM_VER})
  set(CRTM_VER $ENV{CRTM_VER})
  STRING(REGEX REPLACE "v" "" CRTM_VER ${CRTM_VER})
endif()

set (CORE_DEPS " ")
set( NO_DEFAULT_PATH )
if(NOT  BUILD_CRTM )
  if(DEFINED ENV{CRTM_LIB} )
    set(CRTM_LIBRARY $ENV{CRTM_LIB} )
    set(CRTMINC $ENV{CRTM_INC} )
    message("CRTM library ${CRTM_LIBRARY} set via Environment variable")
  else()
  findInc( crtm CRTM_VER CRTMINC )
  find_library( CRTM_LIBRARY 
    NAMES libcrtm_v${CRTM_VER}.a libcrtm.a libCRTM.a 
    HINTS 
      /usr/local/jcsda/nwprod_gdas_2014	
      ${CRTM_BASE}
      ${CRTM_BASE}/lib
      ${CRTM_BASE}/${CRTM_VER}
      ${CRTM_BASE}/${CRTM_VER}/lib
      ${CRTM_BASE}/v${CRTM_VER}/intel
      ${COREPATH}
      ${COREPATH}/lib
      $ENV{COREPATH} 
      $ENV{COREPATH}/lib 
      $ENV{COREPATH}/include 
      ${CORECRTM}/crtm/${CRTM_VER}
      /nwprod2/lib/crtm/v${CRTM_VER}
    PATH_SUFFIXES
        lib
     ${NO_DEFAULT_PATH})
    set( crtm "crtm_v${CRTM_VER}")
    message("Found CRTM library ${CRTM_LIBRARY}")
  endif()
else()
    if( NOT DEFINED ENV{CRTM_SRC} )
      if( FIND_SRC ) 
        findSrc( "crtm" CRTM_VER CRTM_DIR )
        set(CRTMINC  "${CMAKE_BINARY_DIR}/include")
      endif()
    else()
      set( CRTM_DIR "$ENV{CRTM_SRC}/libsrc" CACHE STRING "CRTM Source Location")
      set(CRTMINC  "${CORECRTM}/crtm/${CRTM_VER}/incmod/crtm_v${CRTM_VER}")
    endif()
    set( libsuffix "_v${CRTM_VER}${debug_suffix}" )
    set( CRTM_LIBRARY "${LIBRARY_OUTPUT_PATH}/libcrtm${libsuffix}.a" CACHE STRING "CRTM Library" )
    set( crtm "crtm${libsuffix}")
endif()
if( CORE_LIBRARIES )
  list( APPEND CORE_LIBRARIES ${CRTM_LIBRARY} )
else()
  set( CORE_LIBRARIES ${CRTM_LIBRARY} )
endif()
if( CORE_INCS )
  list( APPEND CORE_INCS ${CRTMINC} )
else()
  set( CORE_INCS ${INCLUDE_OUTPUT_PATH} ${CRTMINC} )
endif()

set( CRTM_LIBRARY_PATH ${CRTM_LIBRARY} CACHE STRING "CRTM Library Location" )
set( CRTM_INCLUDE_PATH ${CRTMINC} CACHE STRING "CRTM Include Location" )


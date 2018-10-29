# Install script for directory: /scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi/ProdGSI

# Set the install prefix
IF(NOT DEFINED CMAKE_INSTALL_PREFIX)
  SET(CMAKE_INSTALL_PREFIX "/scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi")
ENDIF(NOT DEFINED CMAKE_INSTALL_PREFIX)
STRING(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
IF(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  IF(BUILD_TYPE)
    STRING(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  ELSE(BUILD_TYPE)
    SET(CMAKE_INSTALL_CONFIG_NAME "RELEASE")
  ENDIF(BUILD_TYPE)
  MESSAGE(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
ENDIF(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)

# Set the component getting installed.
IF(NOT CMAKE_INSTALL_COMPONENT)
  IF(COMPONENT)
    MESSAGE(STATUS "Install component: \"${COMPONENT}\"")
    SET(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  ELSE(COMPONENT)
    SET(CMAKE_INSTALL_COMPONENT)
  ENDIF(COMPONENT)
ENDIF(NOT CMAKE_INSTALL_COMPONENT)

# Install shared libraries without execute permission?
IF(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  SET(CMAKE_INSTALL_SO_NO_EXE "0")
ENDIF(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)

IF(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for each subdirectory.
  INCLUDE("/scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi/ProdGSI/build_efsoi/libsrc/wrflib/cmake_install.cmake")
  INCLUDE("/scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi/ProdGSI/build_efsoi/libsrc/ncdiag/cmake_install.cmake")
  INCLUDE("/scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi/ProdGSI/build_efsoi/src/cmake_install.cmake")
  INCLUDE("/scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi/ProdGSI/build_efsoi/src/enkf/cmake_install.cmake")
  INCLUDE("/scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi/ProdGSI/build_efsoi/util/EFSOI_Utilities/src/cmake_install.cmake")
  INCLUDE("/scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi/ProdGSI/build_efsoi/util/ndate/cmake_install.cmake")

ENDIF(NOT CMAKE_INSTALL_LOCAL_ONLY)

IF(CMAKE_INSTALL_COMPONENT)
  SET(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
ELSE(CMAKE_INSTALL_COMPONENT)
  SET(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
ENDIF(CMAKE_INSTALL_COMPONENT)

FILE(WRITE "/scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi/ProdGSI/build_efsoi/${CMAKE_INSTALL_MANIFEST}" "")
FOREACH(file ${CMAKE_INSTALL_MANIFEST_FILES})
  FILE(APPEND "/scratch4/NCEPDEV/da/save/David.Groff/David.Groff/version_revised_fv3efsoi/ProdGSI/build_efsoi/${CMAKE_INSTALL_MANIFEST}" "${file}\n")
ENDFOREACH(file)

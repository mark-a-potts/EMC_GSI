set(intsize 4)
function(set_LIBRARY_UTIL_Intel)
    set(BACIO_Fortran_FLAGS "-O3 -free -assume nocc_omp ${HOST_FLAG} " CACHE INTERNAL "" )
    set(BUFR_Fortran_FLAGS "-O2 -r8 -fp-model strict -traceback -O3 ${HOST_FLAG} ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(BUFR_C_FLAGS "-DSTATIC_ALLOCATION -DUNDERSCORE -DNFILES=32 -DMAXCD=250 -DMAXNC=600 -DMXNAF=3" CACHE INTERNAL "" )
    set(BUFR_Fortran_PP_FLAGS " -P -traditional-cpp -C  " CACHE INTERNAL "" )
    set(WRFLIB_Fortran_FLAGS "-DPOUND_FOR_STRINGIFY -O3 -fp-model source -assume byterecl -convert big_endian -g -traceback -D_REAL8_ ${MPI_Fortran_COMPILE_FLAGS}" CACHE INTERNAL "")
    set(WRFLIB_C_FLAGS "-I. -DFortranByte=char -DFortranInt=int -DFortranLlong='long long'  -O3  -Dfunder" CACHE INTERNAL "" )
    set (CRTM_Fortran_FLAGS " -O3 -convert big_endian -free -assume byterecl -fp-model source -traceback ${HOST_FLAG}" CACHE INTERNAL "" )
    set (NEMSIO_Fortran_FLAGS " -O2 -convert big_endian -free -assume byterecl -fp-model strict -traceback ${HOST_FLAG} -g ${MKL_FLAG} ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (SFCIO_Fortran_FLAGS "  -O2 -convert big_endian -free -assume byterecl -fp-model strict -traceback ${HOST_FLAG} -g ${MKL_FLAG} ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (SIGIO_Fortran_FLAGS "  -O2 -convert big_endian -free -assume byterecl -fp-model strict -traceback ${HOST_FLAG} -g ${MKL_FLAG} ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (SP_Fortran_FLAGS " -O2 -ip -fp-model strict -assume byterecl -convert big_endian -fpp -i${intsize} -r8 -convert big_endian -assume byterecl -DLINUX  ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (SP_Fortran_4_FLAGS " -O2 -ip -fp-model strict -assume byterecl -convert big_endian -fpp -i${intsize}     -convert big_endian -assume byterecl -DLINUX  ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (SP_F77_FLAGS " -DLINUX -O2 -ip -fp-model strict -assume byterecl -convert big_endian -fpp -i${intsize} -r8 -convert big_endian -assume byterecl -DLINUX ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (W3EMC_Fortran_FLAGS   " -O3 -auto -assume nocc_omp -i${intsize} -r8 -convert big_endian -assume byterecl -fp-model strict ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (W3EMC_4_Fortran_FLAGS " -O3 -auto -assume nocc_omp -i${intsize}     -convert big_endian -assume byterecl -fp-model strict ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (W3NCO_Fortran_FLAGS   " -O3 -auto -assume nocc_omp -i${intsize} -r8 -convert big_endian -assume byterecl -fp-model strict ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (W3NCO_4_Fortran_FLAGS " -O3 -auto -assume nocc_omp -i${intsize}     -convert big_endian -assume byterecl -fp-model strict ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set (W3NCO_C_FLAGS "-O0 -DUNDERSCORE -DLINUX -D__linux__ " CACHE INTERNAL "" )
    set (NDATE_Fortran_FLAGS "${HOST_FLAG} -fp-model source -ftz -assume byterecl -convert big_endian -heap-arrays  -DCOMMCODE -DLINUX -DUPPLITTLEENDIAN -O3 -Wl,-noinhibit-exec" CACHE INTERNAL "" )
    set(NCDIAG_Fortran_FLAGS "-free -assume byterecl -convert big_endian" CACHE INTERNAL "" )
    set(FV3GFS_NCIO_Fortran_FLAGS "-free" CACHE INTERNAL "" )
    set(UTIL_Fortran_FLAGS "-O3 ${HOST_FLAG} -warn all -implicitnone -traceback -fp-model strict -convert big_endian -DWRF -D_REAL8_ ${OpenMP_Fortran_FLAGS}" CACHE INTERNAL "")
    set(UTIL_COM_Fortran_FLAGS "-O3 -fp-model source -convert big_endian -assume byterecl -implicitnone" CACHE INTERNAL "")
#    set(COV_CALC_FLAGS "-O3 ${HOST_FLAG} -warn all -implicitnone -traceback -fp-model strict -convert little_endian -D_REAL8_ -openmp -fpp -auto" CACHE INTERNAL "" )
   set(COV_CALC_FLAGS "-O3 ${HOST_FLAG} -warn all -implicitnone -traceback -fp-model strict -convert little_endian ${OpenMP_Fortran_FLAGS}" CACHE INTERNAL "")
#   set(COV_CALC_FLAGS ${GSI_Intel_Platform_FLAGS} CACHE INTERNAL "Full GSI Fortran FLAGS" )
endfunction(set_LIBRARY_UTIL_Intel)

function(set_LIBRARY_UTIL_Debug_Intel)
    set (BACIO_Fortran_FLAGS "-g -free -assume nocc_omp " CACHE INTERNAL "" )
    set(BUFR_Fortran_FLAGS " -c -g -traceback -O3 -axCORE-AVX2 -r8 " CACHE INTERNAL "" )
    set(BUFR_C_FLAGS "-g -traceback -DUNDERSCORE -O3 -axCORE-AVX2 -DDYNAMIC_ALLOCATION -DNFILES=32 -DMAXCD=250 -DMAXNC=600 -DMXNAF=3" CACHE INTERNAL "" )
    set(BUFR_Fortran_PP_FLAGS " -P -traditional-cpp -C  " CACHE INTERNAL "" )
    set(CRTM_Fortran_FLAGS " -convert big_endian -free -assume byterecl  -xHOST -fp-model strict -traceback -g ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(SFCIO_Fortran_FLAGS "  -convert big_endian -free -assume byterecl  -xHOST  -fp-model strict -traceback  -g ${MKL_FLAG} ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(SIGIO_Fortran_FLAGS "  -convert big_endian -free -assume byterecl  -xHOST  -fp-model strict -traceback  -g ${MKL_FLAG} ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(SP_Fortran_FLAGS   " -g -ip -fp-model strict -assume byterecl -fpp -i${intsize} -r8 -convert big_endian  -DLINUX  ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(SP_Fortran_4_FLAGS " -g -ip -fp-model strict -assume byterecl -fpp -i${intsize}     -convert big_endian  -DLINUX  ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(SP_F77_FLAGS " -g -ip -fp-model strict -assume byterecl -convert big_endian -fpp -i${intsize} -r8 -DLINUX ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(W3EMC_Fortran_FLAGS   " -g -auto -assume nocc_omp -i${intsize} -r8 -convert big_endian -assume byterecl -fp-model strict ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(W3EMC_4_Fortran_FLAGS " -g -auto -assume nocc_omp -i${intsize}     -convert big_endian -assume byterecl -fp-model strict ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(NEMSIO_Fortran_FLAGS " -convert big_endian -free -assume byterecl -xHOST -fp-model strict -traceback  -g ${MKL_FLAG} ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(W3NCO_Fortran_FLAGS   " -g -auto -assume nocc_omp -i${intsize} -r8 -convert big_endian -assume byterecl -fp-model strict ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(W3NCO_4_Fortran_FLAGS " -g -auto -assume nocc_omp -i${intsize}     -convert big_endian -assume byterecl -fp-model strict ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
    set(W3NCO_C_FLAGS "-O0 -g -DUNDERSCORE -DLINUX -D__linux__ " CACHE INTERNAL "" )
    set(NCDIAG_Fortran_FLAGS "-free -assume byterecl -convert big_endian" CACHE INTERNAL "" )
    set(WRFLIB_Fortran_FLAGS "-DPOUND_FOR_STRINGIFY -O1 -g -fp-model source -assume byterecl -convert big_endian -g -traceback -D_REAL8_ ${MPI_Fortran_COMPILE_FLAGS}" CACHE INTERNAL "")
    set(NDATE_Fortran_FLAGS "${HOST_FLAG} -fp-model source -ftz -assume byterecl -convert big_endian -heap-arrays  -DCOMMCODE -DLINUX -DUPPLITTLEENDIAN -g -Wl,-noinhibit-exec" CACHE INTERNAL "" )
    set(WRFLIB_C_FLAGS "-I. -DFortranByte=char -DFortranInt=int -DFortranLlong='long long'  -g  -Dfunder" CACHE INTERNAL "" )
    set(UTIL_Fortran_FLAGS "-O0 ${HOST_FLAG} -warn all -implicitnone -traceback -g -debug full -fp-model strict -convert big_endian -D_REAL8_ ${OpenMP_Fortran_FLAGS}" CACHE INTERNAL "")
    set(UTIL_COM_Fortran_FLAGS "-O0 -warn all -implicitnone -traceback -g -debug full -fp-model strict -convert big_endian" CACHE INTERNAL "")
    set(COV_CALC_FLAGS "-O3 ${HOST_FLAG} -implicitnone -traceback -fp-model strict -convert little_endian ${OpenMP_Fortran_FLAGS} " CACHE INTERNAL "" )
endfunction(set_LIBRARY_UTIL_Debug_Intel)

function(set_GSI_ENKF_Intel)
    #Common release/production flags
    set(GSI_CFLAGS "-I. -DFortranByte=char -DFortranInt=int -DFortranLlong='long long'  -O3  -Dfunder" CACHE INTERNAL "" )
    set(GSI_Fortran_FLAGS "${GSI_Intel_Platform_FLAGS} ${GSDCLOUDOPT}" CACHE INTERNAL "Full GSI Fortran FLAGS" )
    set(ENKF_Fortran_FLAGS "${ENKF_Platform_FLAGS} ${GSDCLOUDOPT}" CACHE INTERNAL "Full ENKF Fortran FLAGS" )
    set(GSDCLOUD_Fortran_FLAGS "-O3 -convert big_endian" CACHE INTERNAL "")
endfunction(set_GSI_ENKF_Intel)

function (set_GSI_ENKF_Debug_Intel)
    set(GSI_Fortran_FLAGS "-DPOUND_FOR_STRINGIFY -O0 -fp-model source -convert big_endian -assume byterecl -implicitnone -mcmodel medium -shared-intel -g -traceback -debug -ftrapuv -check all,noarg_temp_created -fp-stack-check -fstack-protector -warn all,nointerfaces -convert big_endian -implicitnone -D_REAL8_ ${OpenMP_Fortran_FLAGS} ${MPI_Fortran_COMPILE_FLAGS} ${GSDCLOUDOPT}" CACHE INTERNAL "")
    set(ENKF_Fortran_FLAGS "-O0 ${HOST_FLAG} -warn all -implicitnone -traceback -g -debug all -check all,noarg_temp_created -fp-model strict -convert big_endian -assume byterecl -D_REAL8_ ${MPI3FLAG} ${OpenMP_Fortran_FLAGS} ${GSDCLOUDOPT}" CACHE INTERNAL "")
    set(GSDCLOUD_Fortran_FLAGS "-DPOUND_FOR_STRINGIFY -O3 -convert big_endian" CACHE INTERNAL "")
    #Common debug flags
    set(GSI_CFLAGS "-I. -DFortranByte=char -DFortranInt=int -DFortranLlong='long long'  -g  -Dfunder" CACHE INTERNAL "" )
endfunction (set_GSI_ENKF_Debug_Intel)

function (setIntel)
  string(REPLACE "." ";" COMPILER_VERSION_LIST ${CMAKE_C_COMPILER_VERSION})
  list(GET COMPILER_VERSION_LIST 0 MAJOR_VERSION)
  list(GET COMPILER_VERSION_LIST 1 MINOR_VERSION)
  list(GET COMPILER_VERSION_LIST 2 PATCH_VERSION)
  set(COMPILER_VERSION "${MAJOR_VERSION}.${MINOR_VERSION}.${PATCH_VERSION}" CACHE INTERNAL "Compiler Version") 
  set(COMPILER_TYPE "intel" CACHE INTERNAL "Compiler brand")
  STRING(COMPARE EQUAL ${CMAKE_BUILD_TYPE} "RELEASE" BUILD_RELEASE)
  STRING(COMPARE EQUAL ${CMAKE_BUILD_TYPE} "PRODUCTION" BUILD_PRODUCTION)
  set(EXTRA_LINKER_FLAGS ${MKL_FLAG} CACHE INTERNAL "Extra Linker flags")
  if( (BUILD_RELEASE) OR (BUILD_PRODUCTION) )
    set_GSI_ENKF_Intel()
    set_LIBRARY_UTIL_Intel()
  else( ) #DEBUG flags
    message("Building DEBUG version of GSI")
    set( debug_suffix "_DBG" CACHE INTERNAL "" )
    set_GSI_ENKF_Debug_Intel()
    set_LIBRARY_UTIL_Debug_Intel()
  endif()
endfunction()


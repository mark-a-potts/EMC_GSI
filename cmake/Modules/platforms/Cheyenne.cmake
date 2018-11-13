function (setCheyenne)
  message("Setting paths for Cheyenne")
  set(HOST_FLAG "-xHOST" CACHE INTERNAL "Host Flag")
  set(MKL_FLAG "-mkl"  CACHE INTERNAL "MKL Flag")
  set(GSI_Platform_FLAGS "-DPOUND_FOR_STRINGIFY -O3 -fp-model source -assume byterecl -convert big_endian -g -traceback -D_REAL8_ ${OMPFLAG} ${MPI_Fortran_COMPILE_FLAGS}" CACHE INTERNAL "GSI Fortran Flags")
  set(ENKF_Platform_FLAGS "-O3 ${HOST_FLAG} -warn all -implicitnone -traceback -fp-model strict -convert big_endian -DGFS -D_REAL8_ ${MPI3FLAG} ${OMPFLAG}" CACHE INTERNAL "ENKF Fortran Flags")
# if( NOT DEFINED ENV{WRFPATH} )
#   set(WRFPATH "/glade/p/work/wrfhelp/PRE_COMPILED_CODE_CHEYENNE/WRFV3.9_intel_dmpar_large-file" PARENT_SCOPE )
# else()
#   set(WRFPATH $ENV{WRFPATH} PARENT_SCOPE )
# endif()
  set(BUILD_CORELIBS "ON" )
  set(BUILD_UTIL "OFF" CACHE INTERNAL "" )
  set(BUILD_BUFR "ON" CACHE INTERNAL "")
  set(BUILD_SFCIO "ON" CACHE INTERNAL "")
  set(BUILD_SIGIO "ON" CACHE INTERNAL "")
  set(BUILD_W3EMC "ON" CACHE INTERNAL "")
  set(BUILD_W3NCO "ON" CACHE INTERNAL "")
  set(BUILD_BACIO "ON" CACHE INTERNAL "")
  set(BUILD_CRTM "ON" CACHE INTERNAL "")
  set(BUILD_SP "ON" CACHE INTERNAL "")
  set(BUILD_NEMSIO "ON" CACHE INTERNAL "")
  set(ENV{MPI_HOME} $ENV{MPI_ROOT} )
endfunction()


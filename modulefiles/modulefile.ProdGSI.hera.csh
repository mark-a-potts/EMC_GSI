#%Module######################################################################
##                                                       Russ.Treadon@noaa.gov
##                                                           NOAA/NWS/NCEP/EMC
## GDAS_ENKF v6.2.3
##_____________________________________________________
#set ver v6.2.3

setenv COMP ifort
setenv COMP_MP mpfort
setenv COMP_MPI mpiifort

setenv C_COMP icc
setenv C_COMP_MP mpcc

# Known conflicts

# Load compiler, mpi, cmake, and hdf5/netcdf
module load intel/18.0.5.274
module load impi/2018.0.4
module load hdf5/1.10.4
module load netcdf/4.6.1
module load contrib
module load cmake/3.9.0

# Load libraries
module use /scratch2/NCEPDEV/nwprod/NCEPLIBS/modulefiles
module load bacio/2.0.3
module load bufr/11.3.0
module load crtm/2.2.6
module load nemsio/2.2.4
module load prod_util/1.1.0
module load sfcio/1.1.1
module load sigio/2.1.1
module load sp/2.0.3
module load w3emc/2.3.1
module load w3nco/2.0.7

# Set environmental variables to allow correlated error to reproduce on Hera
setenv MKL_NUM_THREADS 4
setenv MKL_CBWR AUTO

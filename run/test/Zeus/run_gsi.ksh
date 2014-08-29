#!/bin/ksh
#####################################################
# machine set up (users should change this part)
#####################################################
#

# Set the queueing options 
#PBS -l procs=4
#PBS -l walltime=0:10:00
#PBS -A wrfruc
#PBS -N comgsi
#PBS -q debug
#PBS -j oe

set -x
np=$PBS_NP

module load pgi
module load mpt

#
# GSIPROC = processor number used for GSI analysis
#------------------------------------------------
  GSIPROC=4
  ARCH='LINUX_PBS' 
# Supported configurations:
            # IBM_LSF,
            # LINUX, LINUX_LSF, LINUX_PBS,
            # DARWIN_PGI
#
#####################################################
# case set up (users should change this part)
#####################################################
#
# ANAL_TIME= analysis time  (YYYYMMDDHH)
# WORK_ROOT= working directory, where GSI runs
# PREPBURF = path of PreBUFR conventional obs
# BK_FILE  = path and name of background file
# OBS_ROOT = path of observations files
# FIX_ROOT = path of fix files
# GSI_EXE  = path and name of the gsi executable 
  TESTROOT=/scratch1/portfolios/BMC/wrfruc/mhu/code/EMC/gsi/trunk_r42090/
  ANAL_TIME=2008051112
  WORK_ROOT=${TESTROOT}/test/gsiprd_${ANAL_TIME}_arw_trunk
  PREPBUFR=/scratch1/portfolios/BMC/wrfruc/mhu/code/comGSI/data/DTC/obs/newgblav.20080511.ruc2a.t12z.prepbufr
  BK_FILE=/scratch1/portfolios/BMC/wrfruc/mhu/code/comGSI/data/DTC/bkARW/wrfout_d01_2008-05-11_12:00:00
  OBS_ROOT=/scratch1/portfolios/BMC/wrfruc/mhu/code/comGSI/data/DTC/obs
  FIX_ROOT=${TESTROOT}/fix
  CRTM_ROOT=/scratch1/portfolios/NCEPDEV/da/save/Michael.Lueken/nwprod/lib/sorc/CRTM_REL-2.1.3
  GSI_EXE=${TESTROOT}/src/global_gsi
  GSI_EXE=/scratch1/portfolios/BMC/wrfruc/mhu/code/EMC/gsi/trunk_r42090/test/src/global_gsi

#------------------------------------------------
# bk_core= which WRF core is used as background (NMM or ARW)
# bkcv_option= which background error covariance and parameter will be used 
#              (GLOBAL or NAM)
# if_clean = clean  : delete temperal files in working directory (default)
#            no     : leave running directory as is (this is for debug only)
  bk_core=ARW
  bkcv_option=NAM
  if_clean=clean
#
#
#####################################################
# Users should NOT change script after this point
#####################################################
#
BYTE_ORDER=Big_Endian

case $ARCH in
   'IBM_LSF')
      ###### IBM LSF (Load Sharing Facility)
      RUN_COMMAND="mpirun.lsf " ;;

   'LINUX')
      if [ $GSIPROC = 1 ]; then
         #### Linux workstation - single processor
         RUN_COMMAND=""
      else
         ###### Linux workstation -  mpi run
        RUN_COMMAND="mpirun -np ${GSIPROC} -machinefile ~/mach "
      fi ;;

   'LINUX_LSF')
      ###### LINUX LSF (Load Sharing Facility)
      RUN_COMMAND="mpirun.lsf " ;;

   'LINUX_PBS')
      #### Linux cluster PBS (Portable Batch System)
      RUN_COMMAND="mpirun -np ${GSIPROC} " ;;

   'DARWIN_PGI')
      ### Mac - mpi run
      if [ $GSIPROC = 1 ]; then
         #### Mac workstation - single processor
         RUN_COMMAND=""
      else
         ###### Mac workstation -  mpi run
         RUN_COMMAND="mpirun -np ${GSIPROC} -machinefile ~/mach "
      fi ;;

   * )
     print "error: $ARCH is not a supported platform configuration."
     exit 1 ;;
esac


##################################################################################
# Check GSI needed environment variables are defined and exist
#
 
# Make sure ANAL_TIME is defined and in the correct format
if [ ! "${ANAL_TIME}" ]; then
  echo "ERROR: \$ANAL_TIME is not defined!"
  exit 1
fi

# Make sure WORK_ROOT is defined and exists
if [ ! "${WORK_ROOT}" ]; then
  echo "ERROR: \$WORK_ROOT is not defined!"
  exit 1
fi

# Make sure the background file exists
if [ ! -r "${BK_FILE}" ]; then
  echo "ERROR: ${BK_FILE} does not exist!"
  exit 1
fi

# Make sure OBS_ROOT is defined and exists
if [ ! "${OBS_ROOT}" ]; then
  echo "ERROR: \$OBS_ROOT is not defined!"
  exit 1
fi
if [ ! -d "${OBS_ROOT}" ]; then
  echo "ERROR: OBS_ROOT directory '${OBS_ROOT}' does not exist!"
  exit 1
fi

# Set the path to the GSI static files
if [ ! "${FIX_ROOT}" ]; then
  echo "ERROR: \$FIX_ROOT is not defined!"
  exit 1
fi
if [ ! -d "${FIX_ROOT}" ]; then
  echo "ERROR: fix directory '${FIX_ROOT}' does not exist!"
  exit 1
fi

# Set the path to the CRTM coefficients 
if [ ! "${CRTM_ROOT}" ]; then
  echo "ERROR: \$CRTM_ROOT is not defined!"
  exit 1
fi
if [ ! -d "${CRTM_ROOT}" ]; then
  echo "ERROR: fix directory '${CRTM_ROOT}' does not exist!"
  exit 1
fi


# Make sure the GSI executable exists
if [ ! -x "${GSI_EXE}" ]; then
  echo "ERROR: ${GSI_EXE} does not exist!"
  exit 1
fi

# Check to make sure the number of processors for running GSI was specified
if [ -z "${GSIPROC}" ]; then
  echo "ERROR: The variable $GSIPROC must be set to contain the number of processors to run GSI"
  exit 1
fi

#
##################################################################################
# Create the ram work directory and cd into it

workdir=${WORK_ROOT}
echo " Create working directory:" ${workdir}

if [ -d "${workdir}" ]; then
  rm -rf ${workdir}
fi
mkdir -p ${workdir}
cd ${workdir}

#
##################################################################################

echo " Copy GSI executable, background file, and link observation bufr to working directory"

# Save a copy of the GSI executable in the workdir
cp ${GSI_EXE} gsi.exe

# Bring over background field (it's modified by GSI so we can't link to it)
cp ${BK_FILE} ./wrf_inout


# Link to the prepbufr data
ln -s ${PREPBUFR} ./prepbufr

# Link to the radiance data
 ln -s ${OBS_ROOT}/gdas1.t12z.1bamua.tm00.bufr_d amsuabufr
 ln -s ${OBS_ROOT}/gdas1.t12z.1bamub.tm00.bufr_d amsubbufr
 ln -s ${OBS_ROOT}/gdas1.t12z.1bhrs3.tm00.bufr_d hirs3bufr
 ln -s ${OBS_ROOT}/gdas1.t12z.1bhrs4.tm00.bufr_d hirs4bufr
 ln -s ${OBS_ROOT}/gdas1.t12z.1bmhs.tm00.bufr_d mhsbufr
 ln -s ${OBS_ROOT}/gdas1.t12z.gpsro.tm00.bufr_d gpsrobufr
#  ln -s /scratch1/portfolios/BMC/wrfruc/mhu/code/comGSI/releaseV33/release_V3.3_intel/util/radar_process/reflectivity/NSSLRefInGSI.bufr refInGSI
#  ln -s /scratch1/portfolios/BMC/wrfruc/mhu/code/comGSI/releaseV33/release_V3.3_intel/util/radar_process/radialwind/l2rwbufr_new l2rwbufr
#  ln -s /scratch1/portfolios/BMC/wrfruc/mhu/code/comGSI/releaseV33/release_V3.3_intel/util/radar_process/radialwind/radarbufr_new radarbufr
#
##################################################################################

echo " Copy fixed files and link CRTM coefficient files to working directory"

# Set fixed files
#   berror   = forecast model background error statistics
#   specoef  = CRTM spectral coefficients
#   trncoef  = CRTM transmittance coefficients
#   emiscoef = CRTM coefficients for IR sea surface emissivity model
#   aerocoef = CRTM coefficients for aerosol effects
#   cldcoef  = CRTM coefficients for cloud effects
#   satinfo  = text file with information about assimilation of brightness temperatures
#   satangl  = angle dependent bias correction file (fixed in time)
#   pcpinfo  = text file with information about assimilation of prepcipitation rates
#   ozinfo   = text file with information about assimilation of ozone data
#   errtable = text file with obs error for conventional data (regional only)
#   convinfo = text file with information about assimilation of conventional data
#   bufrtable= text file ONLY needed for single obs test (oneobstest=.true.)
#   bftab_sst= bufr table for sst ONLY needed for sst retrieval (retrieval=.true.)

if [ ${bkcv_option} = GLOBAL ] ; then
  echo ' Use global background error covariance'
  BERROR=${FIX_ROOT}/${BYTE_ORDER}/nam_glb_berror.f77.gcv
  OBERROR=${FIX_ROOT}/prepobs_errtable.global
  if [ ${bk_core} = NMM ] ; then
     ANAVINFO=${FIX_ROOT}/anavinfo_ndas_netcdf_glbe
  else
    ANAVINFO=${FIX_ROOT}/anavinfo_arw_netcdf_glbe
  fi
else
  echo ' Use NAM background error covariance'
  BERROR=${FIX_ROOT}/${BYTE_ORDER}/nam_nmmstat_na.gcv
  OBERROR=${FIX_ROOT}/nam_errtable.r3dv
  if [ ${bk_core} = NMM ] ; then
     ANAVINFO=${FIX_ROOT}/anavinfo_ndas_netcdf
  else
     ANAVINFO=${FIX_ROOT}/anavinfo_arw_netcdf
  fi
fi

SATANGL=${FIX_ROOT}/global_satangbias.txt
SATINFO=${FIX_ROOT}/global_satinfo.txt
CONVINFO=${FIX_ROOT}/global_convinfo.txt
OZINFO=${FIX_ROOT}/global_ozinfo.txt
PCPINFO=${FIX_ROOT}/global_pcpinfo.txt

#  copy Fixed fields to working directory
 cp $ANAVINFO anavinfo
 cp $BERROR   berror_stats
 cp $SATANGL  satbias_angle
 cp $SATINFO  satinfo
 cp $CONVINFO convinfo
 cp $OZINFO   ozinfo
 cp $PCPINFO  pcpinfo
 cp $OBERROR  errtable
#
#    # CRTM Spectral and Transmittance coefficients
CRTM_ROOT_ORDER=${CRTM_ROOT}/${BYTE_ORDER}
emiscoef_IRwater=${CRTM_ROOT_ORDER}/Nalli.IRwater.EmisCoeff.bin
emiscoef_IRice=${CRTM_ROOT_ORDER}/NPOESS.IRice.EmisCoeff.bin
emiscoef_IRland=${CRTM_ROOT_ORDER}/NPOESS.IRland.EmisCoeff.bin
emiscoef_IRsnow=${CRTM_ROOT_ORDER}/NPOESS.IRsnow.EmisCoeff.bin
emiscoef_VISice=${CRTM_ROOT_ORDER}/NPOESS.VISice.EmisCoeff.bin
emiscoef_VISland=${CRTM_ROOT_ORDER}/NPOESS.VISland.EmisCoeff.bin
emiscoef_VISsnow=${CRTM_ROOT_ORDER}/NPOESS.VISsnow.EmisCoeff.bin
emiscoef_VISwater=${CRTM_ROOT_ORDER}/NPOESS.VISwater.EmisCoeff.bin
emiscoef_MWwater=${CRTM_ROOT_ORDER}/FASTEM5.MWwater.EmisCoeff.bin
aercoef=${CRTM_ROOT_ORDER}/AerosolCoeff.bin
cldcoef=${CRTM_ROOT_ORDER}/CloudCoeff.bin

ln -s $emiscoef_IRwater ./Nalli.IRwater.EmisCoeff.bin
ln -s $emiscoef_IRice ./NPOESS.IRice.EmisCoeff.bin
ln -s $emiscoef_IRsnow ./NPOESS.IRsnow.EmisCoeff.bin
ln -s $emiscoef_IRland ./NPOESS.IRland.EmisCoeff.bin
ln -s $emiscoef_VISice ./NPOESS.VISice.EmisCoeff.bin
ln -s $emiscoef_VISland ./NPOESS.VISland.EmisCoeff.bin
ln -s $emiscoef_VISsnow ./NPOESS.VISsnow.EmisCoeff.bin
ln -s $emiscoef_VISwater ./NPOESS.VISwater.EmisCoeff.bin
ln -s $emiscoef_MWwater ./FASTEM5.MWwater.EmisCoeff.bin
ln -s $aercoef  ./AerosolCoeff.bin
ln -s $cldcoef  ./CloudCoeff.bin
# Copy CRTM coefficient files based on entries in satinfo file
for file in `awk '{if($1!~"!"){print $1}}' ./satinfo | sort | uniq` ;do
   ln -s ${CRTM_ROOT_ORDER}/${file}.SpcCoeff.bin ./
   ln -s ${CRTM_ROOT_ORDER}/${file}.TauCoeff.bin ./
done

# Only need this file for single obs test
 bufrtable=${FIX_ROOT}/prepobs_prep.bufrtable
 cp $bufrtable ./prepobs_prep.bufrtable

# for satellite bias correction
cp ${FIX_ROOT}/sample.satbias ./satbias_in

#
##################################################################################
# Set some parameters for use by the GSI executable and to build the namelist
echo " Build the namelist "

if [ ${bkcv_option} = GLOBAL ] ; then
#   as_op='0.6,0.6,0.75,0.75,0.75,0.75,1.0,1.0'
   vs_op='0.7,'
   hzscl_op='1.7,0.8,0.5,'
else
#   as_op='1.0,1.0,0.5 ,0.7,0.7,0.5,1.0,1.0,'
   vs_op='1.0,'
   hzscl_op='0.373,0.746,1.50,'
fi

if [ ${bk_core} = NMM ] ; then
   bk_core_arw='.false.'
   bk_core_nmm='.true.'
else
   bk_core_arw='.true.'
   bk_core_nmm='.false.'
fi

# Build the GSI namelist on-the-fly
cat << EOF > gsiparm.anl
 &SETUP
   miter=2,niter(1)=10,niter(2)=10,
   write_diag(1)=.true.,write_diag(2)=.false.,write_diag(3)=.true.,
   gencode=78,qoption=2,
   factqmin=0.0,factqmax=0.0,
   iguess=-1,
   oneobtest=.false.,retrieval=.false.,
   nhr_assimilation=3,l_foto=.false.,
   use_pbl=.false.,
 /
 &GRIDOPTS
   JCAP=62,JCAP_B=62,NLAT=60,NLON=60,nsig=60,regional=.true.,
   wrf_nmm_regional=${bk_core_nmm},wrf_mass_regional=${bk_core_arw},
   diagnostic_reg=.false.,
   filled_grid=.false.,half_grid=.true.,netcdf=.true.,
 /
 &BKGERR
   vs=${vs_op}
   hzscl=${hzscl_op}
   bw=0.,fstat=.true.,
 /
 &ANBKGERR
 /
 &JCOPTS
 /
 &STRONGOPTS
 /
 &OBSQC
   dfact=0.75,dfact1=3.0,noiqc=.false.,c_varqc=0.02,vadfile='prepbufr',
 /
 &OBS_INPUT
   dmesh(1)=120.0,dmesh(2)=60.0,dmesh(3)=60.0,dmesh(4)=60.0,dmesh(5)=120,time_window_max=1.5,
/
OBS_INPUT::
!  dfile          dtype         dplat     dsis                dval    dthin dsfcalc
   prepbufr         ps          null      ps                  0.0     0     0
   prepbufr         t           null      t                   0.0     0     0
   prepbufr         q           null      q                   0.0     0     0
   prepbufr         pw          null      pw                  0.0     0     0
   prepbufr         uv          null      uv                  0.0     0     0
   satwndbufr       uv          null      uv                  0.0     0     0
   prepbufr         spd         null      spd                 0.0     0     0
   prepbufr         dw          null      dw                  0.0     0     0
   radarbufr        rw          null      rw                  0.0     0     0
   prepbufr         sst         null      sst                 0.0     0     0
   gpsrobufr        gps_ref     null      gps                 0.0     0     0
   ssmirrbufr       pcp_ssmi    dmsp      pcp_ssmi            0.0    -1     0
   tmirrbufr        pcp_tmi     trmm      pcp_tmi             0.0    -1     0
   sbuvbufr         sbuv2       n16       sbuv8_n16           0.0     0     0
   sbuvbufr         sbuv2       n17       sbuv8_n17           0.0     0     0
   sbuvbufr         sbuv2       n18       sbuv8_n18           0.0     0     0
   hirs3bufr        hirs3       n17       hirs3_n17           0.0     1     1
   hirs4bufr_skip   hirs4       metop-a   hirs4_metop-a       0.0     1     1
   gimgrbufr        goes_img    g11       imgr_g11            0.0     1     0
   gimgrbufr        goes_img    g12       imgr_g12            0.0     1     0
   airsbufr         airs        aqua      airs281SUBSET_aqua  0.0     1     1
   amsuabufr_skip   amsua       n15       amsua_n15           0.0     1     1
   amsuabufr_skip   amsua       n18       amsua_n18           0.0     1     1
   amsuabufr_skip   amsua       metop-a   amsua_metop-a       0.0     1     1
   airsbufr_skip    amsua       aqua      amsua_aqua          0.0     1     1
   amsubbufr        amsub       n17       amsub_n17           0.0     1     1
   mhsbufr_skip     mhs         n18       mhs_n18             0.0     1     1
   mhsbufr_skip     mhs         metop-a   mhs_metop-a         0.0     1     1
   ssmitbufr        ssmi        f14       ssmi_f14            0.0     1     0
   ssmitbufr        ssmi        f15       ssmi_f15            0.0     1     0
   amsrebufr        amsre_low   aqua      amsre_aqua          0.0     1     0
   amsrebufr        amsre_mid   aqua      amsre_aqua          0.0     1     0
   amsrebufr        amsre_hig   aqua      amsre_aqua          0.0     1     0
   ssmisbufr        ssmis_las   f16       ssmis_f16           0.0     1     0
   ssmisbufr        ssmis_uas   f16       ssmis_f16           0.0     1     0
   ssmisbufr        ssmis_img   f16       ssmis_f16           0.0     1     0
   ssmisbufr        ssmis_env   f16       ssmis_f16           0.0     1     0
   gsnd1bufr_skip   sndrd1      g12       sndrD1_g12          0.0     1     0
   gsnd1bufr_skip   sndrd2      g12       sndrD2_g12          0.0     1     0
   gsnd1bufr_skip   sndrd3      g12       sndrD3_g12          0.0     1     0
   gsnd1bufr_skip   sndrd4      g12       sndrD4_g12          0.0     1     0
   gsnd1bufr_skip   sndrd1      g11       sndrD1_g11          0.0     1     0
   gsnd1bufr_skip   sndrd2      g11       sndrD2_g11          0.0     1     0
   gsnd1bufr        sndrd3      g11       sndrD3_g11          0.0     1     0
   gsnd1bufr_skip   sndrd4      g11       sndrD4_g11          0.0     1     0
   gsnd1bufr_skip   sndrd1      g13       sndrD1_g13          0.0     1     0
   gsnd1bufr_skip   sndrd2      g13       sndrD2_g13          0.0     1     0
   gsnd1bufr_skip   sndrd3      g13       sndrD3_g13          0.0     1     0
   gsnd1bufr_skip   sndrd4      g13       sndrD4_g13          0.0     1     0
   iasibufr         iasi        metop-a   iasi616_metop-a     0.0     1     1
   gomebufr         gome        metop-a   gome_metop-a        0.0     2     0
   omibufr          omi         aura      omi_aura            0.0     2     0
   sbuvbufr         sbuv2       n19       sbuv8_n19           0.0     0     0
   hirs4bufr        hirs4       n19       hirs4_n19           0.0     1     1
   amsuabufr        amsua       n19       amsua_n19           0.0     1     1
   mhsbufr          mhs         n19       mhs_n19             0.0     1     1
   tcvitl           tcp         null      tcp                 0.0     0     0
   mlsbufr          mls30       aura      mls30_aura          1.0     0     0
   seviribufr       seviri      m08       seviri_m08          0.0     1     0
   seviribufr       seviri      m09       seviri_m09          0.0     1     0
   seviribufr       seviri      m10       seviri_m10          0.0     1     0
   hirs4bufr        hirs4       metop-b   hirs4_metop-b       0.0     1     0
   amsuabufr        amsua       metop-b   amsua_metop-b       0.0     1     0
   mhsbufr          mhs         metop-b   mhs_metop-b         0.0     1     0
   iasibufr         iasi        metop-b   iasi616_metop-b     0.0     1     0
   gomebufr         gome        metop-b   gome_metop-b        0.0     2     0
   atmsbufr         atms        npp       atms_npp            0.0     1     0
   crisbufr         cris        npp       cris_npp            0.0     1     0
::
 /
 &SUPEROB_RADAR
   del_azimuth=5.,del_elev=.25,del_range=5000.,del_time=.5,elev_angle_max=5.,minnum=50,range_max=100000.,
   l2superob_only=.false.,
 /
 &LAG_DATA
 /
 &HYBRID_ENSEMBLE
   l_hyb_ens=.false.,
 /
 &RAPIDREFRESH_CLDSURF
 /
 &CHEM
 /
 &SINGLEOB_TEST
   maginnov=1.0,magoberr=0.8,oneob_type='t',
   oblat=38.,oblon=279.,obpres=500.,obdattim=${ANAL_TIME},
   obhourset=0.,
 /

EOF

#
###################################################
#  run  GSI
###################################################
echo ' Run GSI with' ${bk_core} 'background'

case $ARCH in
   'IBM_LSF')
      ${RUN_COMMAND} ./gsi.exe < gsiparm.anl > stdout 2>&1  ;;

   * )
      ${RUN_COMMAND} ./gsi.exe > stdout 2>&1  ;;
esac

##################################################################
#  run time error check
##################################################################
error=$?

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${GSI} crashed  Exit status=${error}"
  exit ${error}
fi
#
##################################################################
#
#   GSI updating satbias_in
#
# GSI updating satbias_in (only for cycling assimilation)

# Copy the output to more understandable names
ln -s stdout      stdout.anl.${ANAL_TIME}
ln -s wrf_inout   wrfanl.${ANAL_TIME}
ln -s fort.201    fit_p1.${ANAL_TIME}
ln -s fort.202    fit_w1.${ANAL_TIME}
ln -s fort.203    fit_t1.${ANAL_TIME}
ln -s fort.204    fit_q1.${ANAL_TIME}
ln -s fort.207    fit_rad1.${ANAL_TIME}

# Loop over first and last outer loops to generate innovation
# diagnostic files for indicated observation types (groups)
#
# NOTE:  Since we set miter=2 in GSI namelist SETUP, outer
#        loop 03 will contain innovations with respect to
#        the analysis.  Creation of o-a innovation files
#        is triggered by write_diag(3)=.true.  The setting
#        write_diag(1)=.true. turns on creation of o-g
#        innovation files.
#

loops="01 03"
for loop in $loops; do

case $loop in
  01) string=ges;;
  03) string=anl;;
   *) string=$loop;;
esac

#  Collect diagnostic files for obs types (groups) below
   listall="conv amsua_metop-a mhs_metop-a hirs4_metop-a hirs2_n14 msu_n14 \
          sndr_g08 sndr_g10 sndr_g12 sndr_g08_prep sndr_g10_prep sndr_g12_prep \
          sndrd1_g08 sndrd2_g08 sndrd3_g08 sndrd4_g08 sndrd1_g10 sndrd2_g10 \
          sndrd3_g10 sndrd4_g10 sndrd1_g12 sndrd2_g12 sndrd3_g12 sndrd4_g12 \
          hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 \
          amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua \
          goes_img_g08 goes_img_g10 goes_img_g11 goes_img_g12 \
          pcp_ssmi_dmsp pcp_tmi_trmm sbuv2_n16 sbuv2_n17 sbuv2_n18 \
          omi_aura ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 amsua_n18 mhs_n18 \
          amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 \
          ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16"
   for type in $listall; do
      count=0
      if [[ -f pe0000.${type}_${loop} ]]; then
         count=`ls pe*${type}_${loop}* | wc -l`
      fi
      if [[ $count -gt 0 ]]; then
         cat pe*${type}_${loop}* > diag_${type}_${string}.${ANAL_TIME}
      fi
   done
done

#  Clean working directory to save only important files 
ls -l * > list_run_directory
if [ ${if_clean} = clean ]; then
  echo ' Clean working directory after GSI run'
  rm -f *Coeff.bin     # all CRTM coefficient files
  rm -f pe0*           # diag files on each processor
  rm -f obs_input.*    # observation middle files
  rm -f siganl sigf03  # background middle files
  rm -f fsize_*        # delete temperal file for bufr size
fi

exit 0

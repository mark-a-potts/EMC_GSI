#!/bin/ksh
#Note: /nwprod version of this file is called JGFS_POSTSND
########################################
# Runs GFS BUFR SOUNDINGS
########################################

export PS4='$SECONDS + '
date
set -xa
# #### 08/25/1999 ###################
# SET SHELL PROCESSING VARIABLES
# ###################################
# 
# obtain unique process id (pid) and make temp directories
#
export pid=$$
#export DATA=/tmpnwprd/${job}.${pid}
#export DATA=${COMOUT:-/$STMP/$LOGNAME/bufrsnd.${pid}}
export DATA=${DATA}/bufrsnd
mkdir $DATA
cd $DATA 

####################################
# File To Log Msgs
####################################
#export jlogfile=/com/logs/jlogfiles/jlogfile.${job}.${pid}

####################################
# Determine Job Output Name on System
####################################
#export outid="LL$job"
#export jobid="${outid}.o${pid}"
export pgmout="OUTPUT.${pid}"
#Set time
export PDY=${CDATE:-2012100100}
export PDY=`echo $PDY |cut -c 1-8`
export cyc=`echo $CDATE |cut -c 9-10`
export cycle=t${cyc}z 

#export SENDCOM=YES
#export SENDECF=YES
#export SENDDBN=YES
export SENDCOM=NO 
export SENDECF=NO 
export SENDDBN=NO 

export NET=gfs
export RUN=gfs
export model=gfs
export pcom=/pcom/gfs

###################################
# Set up the UTILITIES
###################################
export utilities=/nwprod/util/ush
export utilscript=/nwprod/util/ush
export utilexec=/nwprod/util/exec

#export HOMEutil=/nwprod/util
export HOMEutil=$BASEDIR/util
export EXECutil=$HOMEutil/exec
export FIXutil=$HOMEutil/fix
#export PARMutil=$HOMEutil/parm
#export PARMutil=$HOMEutil/parms
export USHutil=$HOMEutil/ush

#export HOMEbufr=/nw${envir}
export HOMEbufr=$BASEDIR
export EXECbufr=$HOMEbufr/exec
export FIXbufr=$HOMEbufr/fix
#export PARMbufr=$HOMEbufr/parm  #nwprod uses parm not parms
export PARMbufr=$HOMEbufr/parms
export USHbufr=$HOMEbufr/ush

export HOMEGLOBAL=/nwprod
export FIXGLOBAL=$HOMEGLOBAL/fix

# Run setup to initialize working directory and utility scripts
#$utilscript/setup.sh
# Run setpdy and initialize PDY variables
#$utilscript/setpdy.sh
#. PDY

##############################
# Define COM Directories
##############################
#export COMIN=/com/${NET}/${envir}/${RUN}.${PDY}
#export COMOUT=/com/${NET}/${envir}/${RUN}.${PDY}
export COMIN=${COMIN:-/com/${NET}/${envir}/${RUN}.${PDY}}
export COMOUT=${COMOUT:-$DATA}
#mkdir -p $COMOUT

#env

########################################################
# Execute the script.
#/nw${envir}/scripts/exgfs_postsnd.sh.ecf
$HOMEbufr/scripts/exgfs_postsnd.sh.ecf
########################################################

cat $pgmout

#cd /tmpnwprd
#rm -rf $DATA
date

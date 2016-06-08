#!/bin/sh
set -x
###############################################################################
## 1. Set date 
## 2. analysis cycle (6hr gdas vs 2.5hr gfs)
## 3. Save directory
###############################################################################
adate=${1:-2012013100}
expt=${2:-prslg4}
savedir=${3:-/ptmp/wx23dc/$expt}
edate=${4:-2012013100}
if [ ! -d $savedir ]; then mkdir -p $savedir || exit 8 ; fi ;
cd $savedir
while [ $adate -le $edate ]; do
YYYY=`echo $adate | cut -c1-4`
MM=`echo $adate | cut -c5-6`
DD=`echo $adate | cut -c7-8`
CYC=`echo $adate | cut -c9-10`
tag=sig
ndate=${ndate_dir}/ndate

/u/wx20mi/bin/hpsstar getnostage /NCEPPROD/1year/hpsspara/runhistory/glopara/$expt/${YYYY}${MM}${DD}${CYC}gfs.sigfa.tar  ${tag}f00.gfs.$adate ${tag}f06.gfs.$adate ${tag}f12.gfs.$adate ${tag}f24.gfs.$adate ${tag}f36.gfs.$adate ${tag}f48.gfs.$adate  


#${tag}f00.gfs.$adate ${tag}f06.gfs.$adate ${tag}f12.gfs.$adate ${tag}f18.gfs.$adate ${tag}f24.gfs.$adate ${tag}f30.gfs.$adate ${tag}f36.gfs.$adate ${tag}f48.gfs.$adate ${tag}f60.gfs.$adate ${tag}f72.gfs.$adate ${tag}f96.gfs.$adate ${tag}f102.gfs.$adate ${tag}f108.gfs.$adate ${tag}f114.gfs.$adate ${tag}f120.gfs.$adate 
#${tag}f126.gfs.$adate ${tag}f132.gfs.$adate ${tag}f144.gfs.$adate ${tag}f156.gfs.$adate ${tag}f168.gfs.$adate

adate=`$ndate +24 $adate`
done
exit
#echo "Finished copying" | mail -s "Finished copying all $expt pgb files" dana.carlis@gmail.com


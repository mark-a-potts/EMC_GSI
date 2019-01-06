#!/bin/sh

set -ex

cd ..
pwd=$(pwd)

build_type=${1:-'PRODUCTION'}
dir_root=${2:-$pwd}

if [[ -d /dcom && -d /hwrf ]] ; then
    . /usrx/local/Modules/3.2.10/init/sh
    target=wcoss
    . $MODULESHOME/init/sh
elif [[ -d /cm ]] ; then
    . $MODULESHOME/init/sh
    target=wcoss_c
elif [[ -d /ioddev_dell ]]; then
    . $MODULESHOME/init/sh
    target=wcoss_d
elif [[ -d /scratch3 ]] ; then
    . /apps/lmod/lmod/init/sh
    target=theia
elif [[ -d /jetmon ]] ; then
    . $MODULESHOME/init/sh
    target=jet
elif [[ -d /glade ]] ; then
    . $MODULESHOME/init/sh
    target=cheyenne
elif [[ -d /sw/gaea ]] ; then
    . /opt/cray/pe/modules/3.2.10.5/init/sh
    target=gaea
else
    echo "unknown target = $target"
    exit 9
fi

dir_modules=$dir_root/modulefiles
if [ ! -d $dir_modules ]; then
    echo "modulefiles does not exist in $dir_modules"
    exit 10
fi
[ -d $dir_root/exec ] || mkdir -p $dir_root/exec

rm -rf $dir_root/build
mkdir -p $dir_root/build
cd $dir_root/build

if [ $target = wcoss -o $target = wcoss_c -o $target = gaea ]; then
    module purge
    module load $dir_modules/modulefile.ProdGSI.$target
    export CRTM_LIB=/gpfs/hps3/emc/da/noscrub/Emily.Liu/RTM/CRTM/REL-2.3.0/crtm_v2.3.0/libcrtm_v2.3.0.a
    export CRTM_INC=/gpfs/hps3/emc/da/noscrub/Emily.Liu/RTM/CRTM/REL-2.3.0/crtm_v2.3.0/incmod/crtm_v2.3.0
elif [ $target = theia -o $target = cheyenne ]; then
    module purge
    source $dir_modules/modulefile.ProdGSI.$target
    export CRTM_LIB=/scratch4/NCEPDEV/da/save/Emily.Liu/RTM/CRTM/releases/REL-2.3.0/crtm_v2.3.0/libcrtm_v2.3.0.a
    export CRTM_INC=/scratch4/NCEPDEV/da/save/Emily.Liu/RTM/CRTM/releases/REL-2.3.0/crtm_v2.3.0/incmod/crtm_v2.3.0
else 
    module purge
    source $dir_modules/modulefile.ProdGSI.$target
fi

cmake -DBUILD_UTIL=ON -DCMAKE_BUILD_TYPE=$build_type -DBUILD_CORELIBS=OFF ..

make -j 8

exit

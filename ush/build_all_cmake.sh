#!/bin/sh

set -ex

cd ..
pwd=$(pwd)

dir_root=${1:-$pwd}

if [[ -d /dcom && -d /hwrf ]] ; then
    . /usrx/local/Modules/3.2.10/init/sh
    target=wcoss
    . $MODULESHOME/init/sh
elif [[ -d /cm ]] ; then
    . $MODULESHOME/init/sh
    conf_target=nco
    target=cray
elif [[ -d /ioddev_dell ]]; then
    . $MODULESHOME/init/bash
    conf_target=nco
    target=dell
elif [[ -d /scratch3 ]] ; then
    . /apps/lmod/lmod/init/sh
    target=theia
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

if [ $target = wcoss -o $target = cray ]; then
    echo "hey loading $dir_modules/modulefile.ProdGSI.$target"
    module load $dir_modules/modulefile.ProdGSI.$target
elif [ $target = theia -o $target = dell ]; then
    echo "hey sourcing $dir_modules/modulefile.ProdGSI.$target"
    source $dir_modules/modulefile.ProdGSI.$target
fi
#module list

cmake -DBUILD_UTIL=ON -DCMAKE_BUILD_TYPE=PRODUCTION ..

make -j 8

exit

#!/bin/sh
set -x
currdir=$(pwd)
cd ../../../
export LIBDIR=$(pwd)/lib
export FCMP=ifort
#export FCMP=xlf_r
cd $currdir
make -f makefile

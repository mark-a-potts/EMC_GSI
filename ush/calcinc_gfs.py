#!/usr/bin/env python
# calcinc_gfs.py
# cory.r.martin@noaa.gov
# 2019-10-10
# script to run calc_increment_ens.x to produce
# increment from background and analysis file difference
import os
import shutil
import subprocess
import sys
import gsi_utils
from collections import OrderedDict

# main function
def calcinc_gfs(DoIAU, l4DEnsVar, Write4Danl, ComOut, APrefix, ASuffix,
                NThreads, IMP_Physics, Inc2Zero, RunDir, Exec, ExecCMD):
  # run the calc_increment_ens executable

  # copy and link files
  if DoIAU and l4DEnsVar and Write4Danl:
    nFH=7
    for fh in range(3,10):
      if fh == 6:
        gsi_utils.link_file('sigf06', 'atmges_mem004')
        gsi_utils.link_file('siganl', 'atmanl_mem004')
        gsi_utils.link_file(ComOut+'/'+APrefix+'atminc', 'atminc_mem004')
      else:
        gsi_utils.link_file('sigf'+format(fh, '02'), 'atmges_mem'+(format(fh-2), '03'))
        gsi_utils.link_file('siga'+format(fh, '02'), 'atmanl_mem'+(format(fh-2), '03'))
        gsi_utils.link_file(ComOut+'/'+APrefix+'atmi'+format(fh, '03'), 'atminc_mem'+(format(fh-2), '03'))
  else:
    nFH=1
    gsi_utils.link_file('sigf06', 'atmges_mem001')
    gsi_utils.link_file('siganl', 'atmanl_mem001')
    gsi_utils.link_file(ComOut+'/'+APrefix+'atminc', 'atminc_mem001')
  os.environ['OMP_NUM_THREADS'] = str(NThreads)
  os.environ['ncmd'] = str(nFH)
  shutil.copy(Exec,RunDir+'/calc_inc.x')
  ExecCMD = ExecCMD.replace("$ncmd",str(nFH))

  # set up the namelist
  namelist = OrderedDict()
  namelist["setup"] =  {"datapath": "'./'",
                        "analysis_filename": "'atmanl'",
                        "firstguess_filename": "'atmges'",
                        "increment_filename": "'atminc'",
                        "debug": ".false.",
                        "nens": str(nFH),
                        "imp_physics": str(IMP_Physics)}

  namelist["zeroinc"] = {"incvars_to_zero": Inc2Zero}
  
  gsi_utils.write_nml(namelist, RunDir+'/calc_increment.nml')

  # run the executable
  try:
    err = subprocess.check_call(ExecCMD+' '+RunDir+'/calc_inc.x', shell=True)
    print(locals())
  except subprocess.CalledProcessError as e:
    print('Error with calc_inc.x, exit code='+str(e.returncode))
    print(locals())
    sys.exit(e.returncode)

# run the function if this script is called from the command line
if __name__ == '__main__':
  DoIAU = gsi_utils.isTrue(os.getenv('DOIAU', 'NO')) 
  l4DEnsVar = gsi_utils.isTrue(os.getenv('l4densvar', 'NO'))
  Write4Danl = gsi_utils.isTrue(os.getenv('lwrite4dan', 'NO'))
  ComOut = os.getenv('COMOUT', './')
  APrefix = os.getenv('APREFIX', '')
  ASuffix= os.getenv('ASUFFIX', '')
  NThreads = os.getenv('NTHREADS_CALCINC', 1)
  IMP_Physics = os.getenv('imp_physics', 11)
  RunDir = os.getenv('DATA', './')
  ExecNC = os.getenv('CALCINCNCEXEC', './calc_increment_ens_ncio.x')
  ExecNEMS = os.getenv('CALCINCEXEC', './calc_increment_ens.x')
  Inc2Zero = os.getenv('INCREMENTS_TO_ZERO', '"NONE"')
  ExecCMD = os.getenv('APRUN_CALCINC', '')

  # determine if the analysis is in netCDF or NEMSIO
  if ASuffix == ".nc":
     Exec = ExecNC
  else:
     Exec = ExecNEMS

  print(locals())
  calcinc_gfs(DoIAU, l4DEnsVar, Write4Danl, ComOut, APrefix, ASuffix,
              NThreads, IMP_Physics, Inc2Zero, RunDir, Exec, ExecCMD)

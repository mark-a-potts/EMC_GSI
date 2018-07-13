#!/bin/sh --login

regtests_all="rtma"

regtests_debug="global_T62
                global_4dvar_T62
                global_4denvar_T126
                global_lanczos_T62
                arw_netcdf
                arw_binary
                nmm_binary
                nmm_netcdf
                nmmb_nems_4denvar
                netcdf_fv3_regional
                hwrf_nmm_d2
                hwrf_nmm_d3"

# Choose which regression test to run; by default, run all
regtests=${1:-$regtests_all}

echo "`pwd`/regression_var.sh" > regression_var.out

for regtest in $regtests; do
    rm -f ${regtest}.out
    echo "Launching regression test: $regtest"
    /bin/sh regression_driver.sh $regtest >& ${regtest}.out &
    sleep 1
done

exit

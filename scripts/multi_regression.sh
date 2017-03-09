#!/bin/sh --login

regtests_all="global_hybrid_T126"

regtests_debug="global_hybrid_T126"

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

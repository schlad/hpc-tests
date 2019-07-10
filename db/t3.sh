#!/bin/bash
#
# This is a POC for running simple HPC tests against the HPC cluster
# provisioned by openQA
#

echo "Test 3"
for (( i = 1; i <= 100; i++ ))
do
    echo "srun job: $i"
    srun -w slave-node00 date
done

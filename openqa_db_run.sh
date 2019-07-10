#!/bin/bash
#
# This is a POC for running simple HPC tests against the HPC cluster
# provisioned by openQA
#

run_basic () {
    echo "Tests execution starts"
    for TEST in ./db/*
        do
	if [ -f $TEST -a -x $TEST ]
	then
            $TEST
        fi
        done
    echo "All tests executed!"
}

run_basic

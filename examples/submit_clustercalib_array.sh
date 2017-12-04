#!/bin/bash
# An example script to submit an array of SLURM jobs.  This should be
# copied and customized for a specific script.

sbatch --nice -a1-$(cat $1 | wc -l)%24 ./slurm_clustercalib_sbu.sh $1

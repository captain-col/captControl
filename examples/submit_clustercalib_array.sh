#!/bin/bash
# An example script to submit an array of SLURM jobs.  This should be
# copied and customized for a specific script.

sbatch --time=48:00:00 --array=1-$(cat $1 | wc -l) ./slurm_clustercalib_pdsf.sh $1

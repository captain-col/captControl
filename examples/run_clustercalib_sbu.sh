#!/bin/bash

# Run a CLUSTERCALIB job as part of a "production".  For instance,
# running one job of a bunch of jobs that are going to run
# clusterCalib on all of the low intensity beam data.
#
# This is customized for the SBU "tree" cluster.
#
# Use the SGE queues
#$ -cwd
#$ -j yes

# Get the arguments off the command line so that we don't confuse CMT
CALIB_FILE=$(realpath $1)
shift

RUN_NUMBER=$(basename ${CALIB_FILE} | sed 's/.*-\([0-9]*\)-.*/\1/')
echo $RUN_NUMBER

CALIB_DIR=$(dirname ${CALIB_FILE})
echo ${CALIB_DIR}

OUTPUT_BASE=$(dirname ${CALIB_DIR})
echo ${OUTPUT_BASE}

######################################################################
######################################################################
# BOILER PLATE THAT CAN BE REUSED: Set the variables at the begining
# (CAPTAIN, JOB_AREA, JOB_PROJECT, and JOB_PACKAGE) to set this up for
# different types of jobs.  The directory that the job should work in
# is set in "JOB_ROOT".
######################################################################
######################################################################

# Adjust to point to the CAPTAIN software installation.  This should
# be the absolute path since batch systems can do evil things to your
# path.
CAPTAIN=/home/captain/export/CAPTAIN

# Adjust to point to the directory to create the job project in.  All of
# the jobs will be run inside the same project.
JOB_AREA=/storage/t2k/CAPTAIN/jobs

# The name of the project to use for this production.
JOB_PROJECT=clustercalib_job

# A template for the name of the package to create for this particular
# job.  This is overwritten with the real job name later.
JOB_PACKAGE="${JOB_PROJECT}.$(date -u +%Y-%m-%d-%H%M )"

# Go to the job area, and then create the project that will be used to
# run the captain software.  The project is not recreated if it
# already exists.
mkdir -p ${JOB_AREA}
cd ${JOB_AREA}
source ${CAPTAIN}/captain.profile

if [ ! -f ${JOB_AREA}/${JOB_PROJECT}/cmt/project.cmt ]; then
   cmt create_project ${JOB_PROJECT} -use=captain-release:master
fi

# Go into the project and then create the package that will be used
# for this particular job.  The job package is created using a mktemp
# based name, so it will be unique.
cd ${JOB_PROJECT}
source ${CAPTAIN}/captain.profile
JOB_PACKAGE=$(basename $(mktemp -d -p . ${JOB_PACKAGE}.XXXXXXXX))
cmt create ${JOB_PACKAGE} v0 

# Go into the job package and get things set up.
cd ${JOB_PACKAGE}/cmt
echo use captainRelease >> requirements
source ${CAPTAIN}/captain.profile

# Make the local directory into the ROOT of the package.
cd ..
JOB_ROOT=${PWD}

######################################################################
######################################################################
######################################################################
######################################################################
# END OF THE BOILER PLATE THAT CAN BE REUSED
######################################################################
######################################################################

# We should already be in "JOB_ROOT".  This is a small reminder to me
# (CDM) that we are in ${JOB_ROOT}
cd ${JOB_ROOT}

# Setup captControl.  This will make sure that the file names and
# logging output is standardized.
source captain-control.bash

captain-experiment nb
captain-data-source mtpc
captain-run-type spl
captain-run-number $RUN_NUMBER

# Let the real work begin.
captain-run-calibration ${CALIB_FILE} -tubdaq -n1 -G miniCAPTAIN

# Move the files to the final locations.
mkdir -p ${OUTPUT_BASE}/cali
mv *_cali_*.root ${OUTPUT_BASE}/cali

mkdir -p ${OUTPUT_BASE}/cali/log
mv captControl*.log ${OUTPUT_BASE}/cali/log



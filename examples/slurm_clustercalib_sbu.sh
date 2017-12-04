#!/bin/bash

# Run a CLUSTERCALIB job as part of a "production".  For instance,
# running one job of a bunch of jobs that are going to run
# clusterCalib on all of the low intensity beam data.
#
# This is customized for the SBU "tree" cluster.  It takes a list of
# files to be process and will process one of them.  The assumption is
# that this will be submitted to the slurm queues using a command
#
# sbatch -a1-N ./run_clustercalib_sbu.sh ubdaq_file.list 
#
# This will process the first N entries in the file list.  The file
# list should have one file per line.  Each line should be either an
# absolute path to the file, or a relative path from the run location.
#
# 

#################################################################
#################################################################
# Gather information from the command line, and break it down into
# usable variables.
#################################################################
#################################################################

# Make the files rw.
umask 002

# Save the file in a local variable.
UBDAQ_FILE_LIST=${1}
shift

# Set the production version (this is the output directory name).
PRODUCTION_VERSION=rdp09
shift

# Get one file out of the file list.
UBDAQ_FILE=$(tail -n +${SLURM_ARRAY_TASK_ID} ${UBDAQ_FILE_LIST} | head -n 1)

# Turn the file into it's real absolute path.
UBDAQ_FILE=$(realpath ${UBDAQ_FILE})
echo ${UBDAQ_FILE}

# Get the run number out of the input file name.
RUN_NUMBER=$(basename ${UBDAQ_FILE} | sed 's/.*-\([0-9]*\)-.*/\1/')
echo ${RUN_NUMBER}

UBDAQ_DIR=$(dirname ${UBDAQ_FILE})
echo ${UBDAQ_DIR}

# Get the base directory for the output.
OUTPUT_BASE=$(dirname ${UBDAQ_DIR})
echo ${OUTPUT_BASE}

OUTPUT_CALI=${OUTPUT_BASE}/calibratedBeam/${PRODUCTION_VERSION}
echo ${OUTPUT_CALI}

OUTPUT_JOBS=${OUTPUT_CALI}/log
echo ${OUTPUT_JOBS}

######################################################################
######################################################################
# BOILER PLATE THAT CAN BE REUSED: Set the variables at the begining
# (CAPTAIN, JOB_AREA, JOB_PROJECT, and JOB_PACKAGE) to set this up for
# different types of jobs.  The directory that the job should work in
# is set in "JOB_ROOT".
#
# This concentrates on making sure that the jobs environment is
# correctly set up.
#
# This boiler plate creates a new cmt package to run a new jobs in and
# sets up the captain software for the run.  This leaves the current
# directory equal to ${JOB_ROOT}.  All of the internal files should be
# written to that directory.
######################################################################
######################################################################

# Adjust directory to point to the CAPTAIN software installation.
# This should be the absolute path since batch systems can do evil
# things to your path.
CAPTAIN=/home/captain/export/CAPTAIN

# Adjust directory to point to the directory to create a job project
# in.  All of the jobs will be run inside the same project.
JOB_AREA=/storage/t2k/CAPTAIN/jobs

# The base name of the project to use for this production.
JOB_PROJECT=clustercalib_${PRODUCTION_VERSION}

# A template for the name of the package to create for this particular
# job.  This is overwritten with the real job name later.
JOB_PACKAGE="${JOB_PROJECT}.$(date -u +%Y-%m-%d-%H%M )"

# Go to the job area, and then create the project that will be used to
# run the captain software.  The project is not recreated if it
# already exists.
mkdir -p ${JOB_AREA}
cd ${JOB_AREA}
source ${CAPTAIN}/captain.profile

while [ ! -f ${JOB_AREA}/${JOB_PROJECT}/cmt/project.cmt ]; do
    if [ ${SLURM_ARRAY_TASK_ID} = "1" ]; then
	cmt create_project ${JOB_PROJECT} -use=captain-release:master
    fi
    echo WAITING FOR ${JOB_PROJECT}
    sleep 2
done
sleep 2

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


######################################################################
######################################################################
# The actual captControl script begins here.
######################################################################
######################################################################

# We should already be in "JOB_ROOT".  This is a small reminder to me
# (CDM) that we are in ${JOB_ROOT}
cd ${JOB_ROOT}

# Setup captControl.  This will make sure that the file names and
# logging output is standardized.
source captain-control.bash

# Define the job information.
captain-experiment nb
captain-data-source mtpc
captain-run-type spl
captain-run-number ${RUN_NUMBER}

# Let the real work begin.
captain-run-calibration ${UBDAQ_FILE} -tubdaq -G miniCAPTAIN

# Move the calibrated files to the final location.
mkdir -p ${OUTPUT_CALI}
mv *_cali_*.root ${OUTPUT_CALI}

# Move the log files to the final location.
mkdir -p ${OUTPUT_JOBS}
mv captControl*.log ${OUTPUT_JOBS}

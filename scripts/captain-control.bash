#!/bin/bash
##
## \file captain-control.bash
## 
## Provide the "library" definitions for captain job control bash
## scripts.  This should be added at the beginning of any job control
## script.
##
## \code
##  source captain-control.bash
## \endcode

# First make sure that this is being executed using bash.
if [ "x" = "x${BASH_VERSION}" ]; then
    echo % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    echo % JOB CONTROL MUST BE RUN USING BASH
    echo % xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    exit 1
fi

# Define the utility functions.
source captain-control-utility.bash

# Define the job identifier, but only if not inheriting one.  The job
# identifier is an internal variable that is mostly useless.  You are
# probably more interested in CAPTAIN_JOB_HASH, or
# CAPTAIN_JOB_FULL_HASH
if [ ${#CAPTAIN_JOB_ID} = 0 ]; then
    export CAPTAIN_JOB_ID=$(captain-uuid)
else
    captain-warning "Multiple initializations with captain-control.bash"
    return
fi

# Write a job summary to a temporary file
captConTmp=$(captain-tempfile)

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"  >> ${captConTmp}
echo "% Starting job at" $(date) >> ${captConTmp}
echo "%   Job Id:" ${CAPTAIN_JOB_ID} >> ${captConTmp}
echo "%   CWD:" $(pwd) >> ${captConTmp}
echo "%   Script:" $0 >> ${captConTmp}
echo "%   Arguments:" $* >> ${captConTmp}
echo "%   System:" $(uname -a) >> ${captConTmp}

# Write the distribution being used.  This only works if we are on an
# lsb system so it only works for linux.
if [ -x /usr/bin/lsb_release ]; then
    echo "%  " $(/usr/bin/lsb_release -i) >> ${captConTmp}
    echo "%  " $(/usr/bin/lsb_release -d) >> ${captConTmp}
    echo "%  " $(/usr/bin/lsb_release -r) >> ${captConTmp}
    echo "%  " $(/usr/bin/lsb_release -c) >> ${captConTmp}
fi

# Write the network names and addresses for this machine
echo "%   Hostname:" $(hostname -f) >> ${captConTmp}
if [ $(captain-system) = "Linux" ]; then
    echo "%   IP Addresses:" $(hostname -i) >> ${captConTmp}
fi

# Generate the tentative job hash code.  This will set the log file
# name (even if it is overridden.
tentativeCaptainHash=$(cat ${captConTmp} | captain-hash | cut -c 1-40)

# Generate the long job hash
export CAPTAIN_JOB_FULL_HASH;
if [ ${#CAPTAIN_JOB_FULL_HASH} = 40 ]; then
    # Set the log file.
    CAPTAIN_JOB_LOG=captControl_${CAPTAIN_JOB_FULL_HASH}.log
    echo | captain-tee
    echo | captain-tee
    echo "CONTINUE JOB AT: " $(date) "XXXXXXXXXXXXXXXXXXXXXXXXXX" | captain-tee
    # Produce a warning
    captain-warning "Override job hash code to continue previous job." 
    captain-warning "Expected hash code:" "${tentativeCaptainHash}"
    captain-warning "New hash code:" "${CAPTAIN_JOB_FULL_HASH}"
elif [ ${#CAPTAIN_JOB_FULL_HASH} != 0 ]; then
    # Set the log file.
    CAPTAIN_JOB_LOG=captControl_${CAPTAIN_JOB_FULL_HASH}.log
    # Clean up before exiting.
    rm ${captConTmp}
    captain-error "Overriding job id with invalid hash code:" \
	"${CAPTAIN_JOB_FULL_HASH}"
else
    CAPTAIN_JOB_FULL_HASH=${tentativeCaptainHash}
fi

# Generate the short hash code for the job.
export CAPTAIN_JOB_HASH=$(echo ${CAPTAIN_JOB_FULL_HASH} | cut -c 1-6)

# Set the log file.
CAPTAIN_JOB_LOG=captControl_${CAPTAIN_JOB_FULL_HASH}.log

echo "%   Job short hash code:" ${CAPTAIN_JOB_HASH}  >> ${captConTmp}
echo "%   Job full hash code: " ${CAPTAIN_JOB_FULL_HASH}   >> ${captConTmp}
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"  >> ${captConTmp}
echo

# Define the main "user" functions.
source captain-control-filenames.bash
source captain-control-jobs.bash

cat ${captConTmp} | captain-tee

rm ${captConTmp}

# An internal function used to implement the cleanup from a job.
function captain-control-cleanup {
    if [ ${#CAPTAIN_OVERRIDES} != 0 ]; then
	if [ -f ${CAPTAIN_OVERRIDES} ]; then
	    rm ${CAPTAIN_OVERRIDES}
	fi
    fi
}
trap captain-control-cleanup EXIT


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

# Define the job identifier, but only if not inheriting one.
if [ ${#CAPTAIN_JOB_ID} = 0 ]; then
    export CAPTAIN_JOB_ID=$(captain-uuid)
else
    captain-warning "Multiple initializations with captain-control.bash"
fi

# Write a job summary to a temporary file
captConTmp=$(captain-tempfile)
echo "%   Job UUID:" ${CAPTAIN_JOB_ID} >> ${captConTmp}
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

# Generate the job hash
export CAPTAIN_JOB_FULL_HASH=$(cat ${captConTmp} | captain-hash | cut -c 1-40)
export CAPTAIN_JOB_HASH=$(echo ${CAPTAIN_JOB_FULL_HASH} | cut -c 1-6)

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "% Starting job at" $(date) 
cat ${captConTmp}
echo "%   Job short hash code:" ${CAPTAIN_JOB_HASH} 
echo "%   Job full hash code: " ${CAPTAIN_JOB_FULL_HASH} 
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo

rm ${captConTmp}

# Define the main "user" functions.
source captain-control-filenames.bash
source captain-control-jobs.bash

# An internal function used to implement the cleanup from a job.
function captain-control-cleanup {
    if [ ${#CAPTAIN_OVERRIDES} != 0 ]; then
	if [ -f ${CAPTAIN_OVERRIDES} ]; then
	    rm ${CAPTAIN_OVERRIDES}
	fi
    fi
}
trap captain-control-cleanup EXIT


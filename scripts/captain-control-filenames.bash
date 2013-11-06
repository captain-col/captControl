#!/bin/bash
#
# This is sourced by the captain-control.bash file.
#

## \page filenameGenerationPage Generating standard filenames

## Functions to generate filenames according to the file naming
##   conventions.

## \section filenameGeneration Filename Generation
##
## The functions in this section are used to set and retrieve
## filenames.  The filenames are constructed according to the \ref
## filenameConvention "file naming conventions".  The captain-file
## function is used to retrieve the names, and the various other
## functions are used to control how the name is constructed.

## \subsection captain-file
## \code
## captain-file step
## \endcode
## \param step The step suffix to use for the file. 
##
## Build a filename based on the current filename parameters.  The
## "step" argument is required and this will exit (return value 1) if
## it is missing.
function captain-file {
    # Make sure that the step has been set.  It's a fatal error if the
    # step is not provided.
    local stepName=$1;
    if [ ${#stepName} = 0 ]; then
	captain-error "The step name must be provided to captain-file"
    fi
    shift

    # Check if there is an extension provided
    local fileExtension=$1
    if [ ${#fileExtension} = 0 ]; then
	fileExtension="root"
    fi

    # Check that all the fields are defined.
    captain-experiment >> /dev/null
    captain-data-source >> /dev/null
    captain-run-type >> /dev/null
    captain-run-number >> /dev/null
    captain-subrun-number >> /dev/null
    captain-processing-version >> /dev/null

    # Build the run number field
    local runNumbering=""
    if [ ${#CAPTAIN_SUBRUN_NUMBER} = 0 ]; then
	printf -v runNumbering "%0.6d_%0.3d" \
	    ${CAPTAIN_RUN_NUMBER} ${CAPTAIN_PROCESSING_VERSION}
    else
	printf -v runNumbering "%0.6d-%0.3d_%0.3d" \
	    ${CAPTAIN_RUN_NUMBER} ${CAPTAIN_SUBRUN_NUMBER} \
	    ${CAPTAIN_PROCESSING_VERSION}
    fi

    # Build the file  hash code
    local fileHash=$(echo ${CAPTAIN_JOB_ID} ${CAPTAIN_EXPERIMENT} \
	${CAPTAIN_DATA_SOURCE} ${CAPTAIN_RUN_TYPE} \
	${runNumbering} ${stepName} \
	${CAPTAIN_JOB_FULL_HASH} ${CAPTAIN_PROCESSING_COMMENT} \
	${fileExtension} | captain-hash | cut -c 1-4)

    # Format the file name.
    if [ ${#CAPTAIN_PROCESSING_COMMENT} = 0 ]; then
	printf "%s_%s_%s_%s_%s_%s%s.%s\n" \
	    "${CAPTAIN_EXPERIMENT}" "${CAPTAIN_DATA_SOURCE}" \
	    "${CAPTAIN_RUN_TYPE}" "${runNumbering}" ${stepName} \
	    "${CAPTAIN_JOB_HASH}" "${fileHash}" "${fileExtension}" 
	return
    fi
    printf "%s_%s_%s_%s_%s_%s%s_%s.%s\n" \
	"${CAPTAIN_EXPERIMENT}" "${CAPTAIN_DATA_SOURCE}" "${CAPTAIN_RUN_TYPE}" \
	"${runNumbering}" ${stepName} \
	"${CAPTAIN_JOB_HASH}" "${fileHash}" \
	"${CAPTAIN_PROCESSING_COMMENT}" "${fileExtension}" 
}

## \subsection captain-experiment
## \code
## captain-experiment name
## \endcode
## or
## \code
## captain-experiment
## \endcode
##
## This sets the experiment name code that will be used in the file
## name.  The code should usually be two charactors, but that is left
## as a user decision.  The standard name codes are defined in the
## \ref filenameConvention "file naming convention".  If this is
## called without an argument, the current value is returned.
export CAPTAIN_EXPERIMENT
function captain-experiment {
    if [ ${#1} != 0 ]; then 
	CAPTAIN_EXPERIMENT=$1
	return
    fi
    if [ ${#CAPTAIN_EXPERIMENT} = 0 ]; then
	CAPTAIN_EXPERIMENT=ee;
	captain-warning "The experiment type was not set." \
	    "Using a default value of ${CAPTAIN_EXPERIMENT}."
    fi
    echo ${CAPTAIN_EXPERIMENT}
}

## \subsection captain-data-source
## \code
## captain-data-source name
## \endcode
## or
## \code
## captain-data-source
## \endcode
##
## This sets the data source name code that will be used in the file
## name.  The code should usually be two charactors, but that is left
## as a user decision.  The standard name codes are defined in the
## \ref filenameConvention "file naming convention".  If this is
## called without an argument, the current value is returned.
export CAPTAIN_DATA_SOURCE
function captain-data-source {
    if [ ${#1} != 0 ]; then 
	CAPTAIN_DATA_SOURCE=$1
	return
    fi
    if [ ${#CAPTAIN_DATA_SOURCE} = 0 ]; then
	CAPTAIN_DATA_SOURCE=ss;
	captain-warning "The data-source type was not set." \
	    "Using a default value of ${CAPTAIN_DATA_SOURCE}."
    fi
    echo ${CAPTAIN_DATA_SOURCE}
}

## \subsection captain-run-type
## \code
## captain-run-type name
## \endcode
## or
## \code
## captain-run-type
## \endcode
##
## This sets the run type name code that will be used in the file
## name.  The code should usually be three charactors, but that is
## left as a user decision.  If a GEANT particle gun is used as the
## data source, then the run type should give the particle name (and
## possible the kinetic energy range as a sub-field).  The standard
## name codes are defined in the
## \ref filenameConvention "file naming convention".  If this is
## called without an argument, the current value is returned.
export CAPTAIN_RUN_TYPE
function captain-run-type {
    if [ ${#1} != 0 ]; then 
	CAPTAIN_RUN_TYPE=$1
	return
    fi
    if [ ${#CAPTAIN_RUN_TYPE} = 0 ]; then
	CAPTAIN_RUN_TYPE=ttt;
	captain-warning "The run type was not set." \
	    "Using a default value of ${CAPTAIN_RUN_TYPE}."
    fi
    echo ${CAPTAIN_RUN_TYPE}
}


## \subsection captain-run-number
## \code
## captain-run-number name
## \endcode
## or
## \code
## captain-run-number
## \endcode
##
## This sets the run number that will be used in the file
## name.  The run number is zero padded to be 8 digits.
export CAPTAIN_RUN_NUMBER
function captain-run-number {
    if [ ${#1} != 0 ]; then 
	CAPTAIN_RUN_NUMBER=$1
	return
    fi
    if [ ${#CAPTAIN_RUN_NUMBER} = 0 ]; then
	CAPTAIN_RUN_NUMBER=0;
	captain-warning "The run number was not set." \
	    "Using a default value of ${CAPTAIN_RUN_NUMBER}."
    fi
    echo ${CAPTAIN_RUN_NUMBER}
}

## \subsection captain-subrun-number
## \code
## captain-subrun-number name
## \endcode
## or
## \code
## captain-subrun-number
## \endcode
##
## This sets the subrun number that will be used in the file
## name.  The subrun number is zero padded to be 3 digits.
export CAPTAIN_SUBRUN_NUMBER
function captain-subrun-number {
    if [ ${#1} != 0 ]; then 
	CAPTAIN_SUBRUN_NUMBER=$1
	return
    fi
    if [ ${#CAPTAIN_SUBRUN_NUMBER} != 0 ]; then
	echo ${CAPTAIN_SUBRUN_NUMBER}
    fi
}

## \subsection captain-processing-version
## \code
## captain-processing-version name
## \endcode
## or
## \code
## captain-processing-version
## \endcode
##
## This sets the process version that will be used in the file
## name.  The run number is zero padded to be 3 digits.
export CAPTAIN_PROCESSING_VERSION
function captain-processing-version {
    if [ ${#1} != 0 ]; then 
	CAPTAIN_PROCESSING_VERSION=$1
	return
    fi
    if [ ${#CAPTAIN_PROCESSING_VERSION} = 0 ]; then
	CAPTAIN_PROCESSING_VERSION=0;
    fi
    echo ${CAPTAIN_PROCESSING_VERSION}
}

## \subsection captain-processing-comment
## \code
## captain-processing-comment name
## \endcode
## or
## \code
## captain-processing-comment
## \endcode
##
## This sets the optional processing comment that will be used in the file
## name.  Any leading or trailing "_" will be removed from the comment.
export CAPTAIN_PROCESSING_COMMENT
function captain-processing-comment {
    if [ ${#1} != 0 ]; then 
	CAPTAIN_PROCESSING_COMMENT=$(echo $1 | \
	    sed -e 's/^_*//' | \
	    sed -e 's/_*$//' )
	return
    fi
    if [ ${#CAPTAIN_PROCESSING_COMMENT} = 0 ]; then
	CAPTAIN_PROCESSING_COMMENT=0;
    fi
    echo ${CAPTAIN_PROCESSING_COMMENT}
}


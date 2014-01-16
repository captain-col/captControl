#!/bin/bash
#
# This is sourced by the captain-control.bash file.
#

## \page jobControlPage Controlling CAPTAIN jobs
##
## Functions to help run CAPTAIN jobs. 

## \section highLevelJobControl Running standard programs.

## These functions are for running the standard event processing chain.

## \subsection captain-run-genie-simple
##
## \code
## captain-run-genie-simple events flux neutrino
## \endcode
##
## This runs the GENIE interaction MC to product ghep (in the native
## GENIE ghep format) and gnmc (in the rootracker) files.  It takes 3
## arguments: the first is the number of events to generate, the
## second is the flux to use, and the third is the pdg code for the
## neutrino type.  The format of the flux is documented in
## captainGENIE.  It is name of a file containing a root histogram
## ("file.root,hist_name"), the name of a text file with two columns
## (energy,flux), or a TF1 function string
## (e.g. "x*x*exp(-(x/5.0)**2)")

function captain-run-genie-simple {
    local events=${1}
    local flux=${2}
    local neutrino=${3}

    if [ ${#1} = 0 ]; then
	captain-error Number of events must be provided as first argument.
	return 1;
    fi

    if [ ${#2} = 0 ]; then
	captain-error Flux must be provided as second argument.
	return 1;
    fi

    if [ ${#3} = 0 ]; then
	captain-error Neutrino PDG MC number must be provided as third argument.
	return 1;
    fi

    local prefix=$(basename $(captain-file "ghep") ".root")
    local filename="${prefix}.$(captain-run-number).ghep.root"
    local loglevel=${GENIE}/config/Messenger_laconic.xml

    gevgen_capt.exe -r $(captain-run-number) \
	-o ${prefix} \
	-n ${events} \
	-e 0.001,15.0 \
        -p ${neutrino} \
        -f ${flux} \
        --seed 0 \
        --event-record-print-level 0 \
	--message-thresholds ${loglevel} |& captain-tee
    gntpc -f rootracker \
        -i ${filename} \
        -o $(captain-file "gnmc") \
	--message-thresholds ${loglevel} |& captain-tee
    
    mv ${filename} $(captain-file "ghep")
    
    # Write a GEANT4 macro file to process the output.
    cat >> $(captain-file "g4in" "mac") <<EOF
/dsim/control baseline 1.0
/dsim/update

/generator/kinematics/rooTracker/input $(captain-file "gnmc")
/generator/kinematics/set rooTracker

# Have exactly one interaction per event.
/generator/count/fixed/number 1
/generator/count/set fixed

# Choose the position based on the density (and only in the drift volume).
/generator/position/density/volume Drift
/generator/position/set density

/generator/add

/run/beamOn ${events}
EOF

}

## \subsection captain-process-detsim-macro
##
## \code
## captain-process-detsim-macro [macro-file.mac]
## \endcode
##
## This takes a detsim macro file (ending with the extension ".mac")
## and runs the DETSIM.exe to produce a g4mc file. The output filename
## is controlled using the usual \ref filenameGeneration routines.  If
## no input macro argument is provided, then this will look for a file
## from the step "g4in" with an extension "mac" (specifically
## "captain-file g4in mac").
function captain-process-detsim-macro {
    local input=${1}
    local output=$(captain-file g4mc)
    if [ ${#1} = 0 ]; then
	if [ -f $(captain-file g4in mac) ]; then
	    input=$(captain-file g4in mac)
	else
	    return 1
	fi
    fi
    if [ ! -f ${input} ]; then
	captain-error "No input macro file for detsim"
	return 1
    fi
    DETSIM.exe -o $(basename ${output} .root) ${input} |& captain-tee
}

## \subsection captain-run-electronics-simulation
##
## \code
## captain-run-electronics-simulation
## \endcode
## 
## Process a file from the g4mc step and produce an "elmc" file.  The
## filenames are controlled using the usual \ref filenameGeneration
## routines. 
function captain-run-electronics-simulation {
    if [ ! -f $(captain-file g4mc) ]; then
	if captain-process-detsim-macro; then
	    captain-log "Processed " $(captain-file g4in mac)
	fi
    fi
    captain-run-standard-event-loop ELECSIM.exe g4mc elmc
}

## \subsection captain-run-calibration
##
## \code
## captain-run-calibration
## \endcode
## 

## Process a file from the raw data or electronics simulation step and
## product a "cali" file.  The filenames are controlled using the usual
## \ref filenameGeneration routines.  For MC, this expects an "elmc" file,
## but if it's missing and it finds a "g4mc" file, it will run the
## electronics simulation using captain-run-electronnics-simulation.  It
## will also look to see if it can find the correct uncalibrated data file
## (i.e. a "digit file" with a step name of "digt").

function captain-run-calibration {
    local input

    # Check to see if we can find the input file.
    if [ -f $(captain-file digt) ]; then
	input=unpk
    elif [ -f $(captain-file elmc) ]; then
	input=elmc
    elif captain-run-digit-unpacker; then
	input=unpk
    elif captain-run-electronics-simulation; then
	input=elmc
    else
	captain-warning "Cannot run calibration since there isn't" \
	    "an input file." 
	return 1
    fi

    # Run the event loop in the standard way.
    captain-run-standard-event-loop CLUSTERCALIB.exe ${input} cali
}

# This is a dummy routine for now...
function captain-run-digit-unpacker {
    return 1
}

## \subsection captain-run-reconstruction
##
## \code
## captain-run-reconstruction
## \endcode
## 

## Process a file from the calibration step and
## product a "reco" file.  The filenames are controlled using the usual
## \ref filenameGeneration routines.  If this can't find a "cali" file,
## then it will automatically run the calibration by calling
## captain-run-calibration. 


function captain-run-reconstruction {
    if [ ! -f $(captain-file cali) ]; then
	captain-run-calibration
    fi 
    captain-run-standard-event-loop CAPTRECON.exe cali reco
}


## \section lowLevelJobControl Lower level control of event-loop programs

## These functions deal with the lower level aspects of running event loop
## programs.  The captain-run-standard-event-loop function can run any
## normal event loop program.  If you want to pass "overrides" to the
## program for the  run-time parameters, this is done using the
## captain-override function. 

## \subsection captain-run-standard-event-loop
## \code
## captain-run-standard-event-loop exe input output
## \endcode
## \param exe The name of the executable to run.  It must be in the path.
## \param input The step name for the input file (e.g. "cali")
## \param output The step name produced by this event-loop.
##
## This is a low level function used to implement other event loop utilities.
function captain-run-standard-event-loop {
    if [ ${#1} = 0 ]; then 
	captain-error "Must provide an executable name."
    fi
    if [ ${#2} = 0 ]; then 
	captain-error "Must provide a step for the input file."
    fi
    if [ ${#3} = 0 ]; then 
	captain-error "Must provide a step for the output file."
    fi
    if ! which ${1} >> /dev/null; then
	captain-error "First argument must be executable."
    fi
    local exeFile=$(which ${1})
    local inputFile=$(captain-file ${2})
    local outputFile=$(captain-file ${3})
    captain-log "Run: " $exeFile
    captain-log "Options: " ${CAPTAIN_EVENT_LOOP_OPTIONS}
    captain-log "Input: " ${inputFile}
    captain-log "Output: " ${outputFile}
    if [ ${#CAPTAIN_OVERRIDES} != 0 ]; then
	captain-log "Override file: " ${CAPTAIN_OVERRIDES}
	cat ${CAPTAIN_OVERRIDES}
	${exeFile} -R ${CAPTAIN_OVERRIDES} ${CAPTAIN_EVENT_LOOP_OPTIONS} \
	    -o ${outputFile} \
	    ${inputFile}
	return
    fi
    ${exeFile} ${CAPTAIN_EVENT_LOOP_OPTIONS} \
	-o ${outputFile} \
	${inputFile} |& captain-tee
}

## \subsection captain-override
## \code
## captain-override parameterName parameterValue
## \endcode
##
## Add a paremeter to the run-time options override file.  These are
## passed to the event loop using the "-R" option, and parsed by the
## TRuntimeParameters class.  The values are override any values set
## in default runtime parameters files.
export CAPTAIN_OVERRIDES
function captain-override {
    if [ ${#1} = 0 ]; then 
	captain-error "Must provide a parameter name to override."
    fi
    if [ ${#2} = 0 ]; then 
	captain-error "Must provide a value for the parameter."
    fi
    if [ ${#CAPTAIN_OVERRIDES} = 0 ]; then
	CAPTAIN_OVERRIDES=$(captain-tempfile)
    fi
    echo "< ${1} = ${2} >" >> ${CAPTAIN_OVERRIDES}
}

## \subsection captain-clear-overrides
## \code
## captain-clear-overrides
## \endcode
##
## Remove all existing override parameters.
function captain-clear-overrides {
    if [ ${#CAPTAIN_OVERRIDES} = 0 ]; then 
	return
    fi
    if [ -f ${CAPTAIN_OVERRIDES} ]; then 
	rm ${CAPTAIN_OVERRIDES}
    fi
    CAPTAIN_OVERRIDES=""
}

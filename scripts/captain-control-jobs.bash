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
## captain-run-genie-simple events flux [geom-macro] [kinem-macro]
## \endcode
##
## This runs the GENIE interaction MC to product ghep (in the native
## GENIE ghep format) and gnmc (in the rootracker) files.  It has two
## required arguments and two optional argument.  The first
## argument is the number of events to generate and the second
## argument is the flux description.  The format of the flux is
## documented in captainGENIE.cxx.
##
## It can be any of:
##
##   - An energy in GeV.  This can't be combined with other flux
##      descriptions. eg `mono,pdg,energy' 
##   - A function (x in GeV):
##      eg `func,pdg,x*x+4*exp(-x),emin,emax' 
##   - A 1-D ROOT histogram (binned in GeV):
##      The general syntax is `hist,pdg,file.root,hist_name'
##   - A text file with columns of energy (in GeV) and flux:
##      The general syntax is `text,pdg,file.txt,Ecol,Fcol' with
##      ECol giving the column with the energy Fcol giving the column
##      with the flux.  The colunms are counted from 0.
##
## If multiple fluxes are specified, then they are separated by a ':',
## `hist,14,file.root,numu:hist,-14,file.root,numubar' would read
## the muon neutrino (pdg 14) flux from the histogram named numu in
## file.root, and the muon anti-neutrino (pdg -14) flux from the
## histogram named numubar in file.root.  This clunky interface is
## forced by the GENIE command line argument parser which can't handle
## multiple copies of an option.
##
## If the third argument is provided, it is the name of a geometry
## control macro for detSim and follows the usual GEANT4 macro syntax.
## It is intended to set the detector parameters for the simulation
## (e.g. CAPTAIN vs mini-CAPTAIN, wire spacing, &c).  The geometry
## control macro must end with a "/dsim/update" command so that the
## detector simulation will build the geometry.  If a geometry control
## macro is not provided, then a default version is used.
##
## \code
## /dsim/random/timeRandomSeed
## /dsim/control baseline 1.0
## /dsim/update
## \endcode
##
## A simple geometry macro to simulate miniCAPTAIN would be:
##
## \code
## /dsim/random/timeRandomSeed
## /dsim/control mini-captain 1.0
## /dsim/update
## \endcode
##
## If the fourth argument is provided, it is the name of a kinematics
## control macro which follows the usual GEANT4 macro syntax.  It is
## intended to override the default uniform vertex distribution, but
## the default definition should work for all but specific special
## case studies.  The default distributes the neutrino vertices within
## the active volume of the TPC with exactly one neutrino interaction
## per event.
##
## \code
## /generator/count/fixed/number 1
## /generator/count/set fixed
## /generator/position/density/sample Drift
## /generator/position/set density
## /generator/add
## \endcode
##
##
## The kinematics control macro can define multiple generators, but
## the first is assumed to take it's kinematics from the GENIE
## rooTracker file.
function captain-run-genie-simple {
    local events=${1}
    local flux=${2}

    if [ ${#1} = 0 ]; then
	captain-error Number of events must be provided as first argument.
	return 1;
    fi

    if [ ${#2} = 0 ]; then
	captain-error Flux must be provided as second argument.
	return 1;
    fi

    local prefix=$(basename $(captain-file "ghep") ".root")
    local filename="${prefix}.$(captain-run-number).ghep.root"

    gevgen_capt.exe -r $(captain-run-number) \
	-o ${prefix} \
	-n ${events} \
	-f ${flux} 2>&1 | captain-tee
    gntpc -f rootracker \
        -i ${filename} \
        -o $(captain-file "gnmc") 2>&1 | captain-tee
    
    mv ${filename} $(captain-file "ghep")
    

    # Tell the GEANT4 macro about the GENIE input kinematics file.
    cat > $(captain-file "g4in" "mac") <<EOF

/generator/kinematics/rooTracker/input $(captain-file "gnmc")
/generator/kinematics/set rooTracker
EOF


    ##################################################
    # Write a GEANT4 macro file to process the output.
    ##################################################

    # Define the detector geometry, set up the random number
    # generator, and define other default values.
    if [ ${#3} != 0 ]; then
	# There is a macro file on the command line.
	cat ${3} >> $(captain-file "g4in" "mac")
    else
	cat >> $(captain-file "g4in" "mac") <<EOF
/dsim/random/timeRandomSeed
/dsim/control baseline 1.0
/dsim/update
EOF
    fi
    

    # Tell the detector simulation how to distribute the interactions
    # in the GENIE file.
    if [ ${#4} != 0 ]; then
	# There is a macro file on the command line.
	cat ${4} >> $(captain-file "g4in" "mac")
    else
	cat >> $(captain-file "g4in" "mac") <<EOF
/generator/count/fixed/number 1
/generator/count/set fixed

/generator/position/density/sample Drift
/generator/position/set density

/generator/add
EOF
   fi

   if grep beamOn $(captain-file "g4in" "mac") >> /dev/null; then
       captain-log "Number of events set in " $(captain-file "g4in" "mac")
   else
       if [ ${#2} != 0 ]; then
	   captain-log "Set number of events to generate"
	   cat >> $(captain-file "g4in" "mac") <<EOF
/run/beamOn ${events}
EOF
       fi
   fi

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
    if ! which DETSIM.exe >> /dev/null; then
	captain-error "The detector simulation is not available."
	return 1
    fi
    DETSIM.exe -o $(basename ${output} .root) ${input} 2>&1 | captain-tee
}

## \subsection captain-run-electronics-simulation
##
## \code
## captain-run-electronics-simulation [detsim-file.root]
## \endcode
## 
## Process a file from the g4mc step and produce an "elmc" file.  The
## filenames are controlled using the usual \ref filenameGeneration
## routines.  Normally, an input file name is built using the standard
## file name routines so the argument "detsim-file.root" won't be
## provided, however, if a non-standard input file needs to be
## processed, the filename can be given as the first argument.  If an
## input file is provided, then the output file name will be
## constructed using the usual \ref filenameGeneration routines. 
## For example,
##
## \code
## captain-experiment nb
## captain-data-source pg
## captain-run-type neutron
## captain-run-number 42
## captain-processing-comment test
##
## captain-run-electronics-simulation detsim-file.root
## captain-run-reconstruction
## \endcode
##
## will use the previously generated detsim-file.root and run the
## electronics simulation to produce a standard output file which is
## then process through the calibration and reconstruction.
##
function captain-run-electronics-simulation {
    local input=g4mc

    if [ ${#1} != 0 ]; then
	# A file was provided as an argument.
	if [ ! -f ${1} ]; then
	    captain-error "Input file" $1 " does not exist"
	    exit 1
	fi
	input=${1}
	shift
    elif [ ! -f $(captain-file g4mc) ]; then
	if captain-process-detsim-macro; then
	    captain-log "Processed " $(captain-file g4in mac)
	fi
    fi
    captain-run-standard-event-loop ELECSIM.exe ${input} elmc
}
	    
## \subsection captain-run-calibration
##
## \code
## captain-run-calibration [filename] [options...]
## \endcode
## 

## Process a file from the raw data or electronics simulation step and
## product a "cali" file.  The filenames are controlled using the
## usual \ref filenameGeneration routines.  For MC, this expects an
## "elmc" file, but if it's missing and it finds a "g4mc" file, it
## will run the electronics simulation using
## captain-run-electronnics-simulation.  It will also look to see if
## it can find the correct uncalibrated data file (i.e. a "digit file"
## with a step name of "digt").  Normally, an input file name is built
## using the standard file name routines so the argument "filename"
## won't be provided, however, if a non-standard input file needs to
## be processed, the filename can be given as the first argument.  The
## remaining arguments are passed to the calibration executable.  If
## an input file is provided, then the output file name will be
## constructed using the usual \ref filenameGeneration routines.
function captain-run-calibration {
    local input

    # Check to see if we can find the input file.
    if [ ${#1} != 0 ]; then
	input=${1}
	shift
    elif [ -f $(captain-file elmc) ]; then
	input=elmc
    elif captain-run-electronics-simulation; then
	input=elmc
    else
	captain-warning "Cannot run calibration since there isn't" \
	    "an input file." 
	return 1
    fi

    # Now check if there are any options
    if [ ${#1} != 0 ]; then
	CAPTAIN_EVENT_LOOP_OPTIONS=${*}
    fi
    
    # Run the event loop in the standard way.
    captain-run-standard-event-loop CLUSTERCALIB.exe ${input} cali

    CAPTAIN_EVENT_LOOP_OPTIONS=""
}

## \subsection captain-run-reconstruction
##
## \code
## captain-run-reconstruction [cali-file.root]
## \endcode
## 

## Process a file from the calibration step and product a "reco" file.
## The filenames are controlled using the usual \ref
## filenameGeneration routines.  If this can't find a "cali" file,
## then it will automatically run the calibration by calling
## captain-run-calibration.  Normally, an input file name is built
## using the standard file name routines so the argument
## "cali-file.root" won't be provided, however, if a non-standard input
## file needs to be processed, the filename can be given as the first
## argument.  If an input file is provided, then the output file name
## will be constructed using the usual \ref filenameGeneration
## routines.

function captain-run-reconstruction {
    local input=cali

    # Check to see if we can find the input file.
    if [ ${#1} != 0 ]; then
	input=${1}
	shift
    elif captain-run-calibration; then
	input=cali
    fi 

    # Now check if there are any options
    if [ ${#1} != 0 ]; then
	CAPTAIN_EVENT_LOOP_OPTIONS=${*}
    fi

    captain-run-standard-event-loop CAPTRECON.exe ${input} reco

    CAPTAIN_EVENT_LOOP_OPTIONS=""
}


## \subsection captain-run-summary
##
## \code
## captain-run-summary [reco-file.root]
## \endcode
## 

## Summarize a file.  This usually takes a "reco" file, but can handle
## any kind of input.  It only summarizes the information that is
## actually available.  The filenames are controlled using the usual
## \ref filenameGeneration routines.  If this can't find a "reco"
## file, then it will automatically run the reconstruction by calling
## captain-run-reconstruction.  Normally, an input file name is built
## using the standard file name routines so the argument
## "reco-file.root" won't be provided, however, if a non-standard
## input file needs to be processed, the filename can be given as the
## first argument.  If an input file is provided, then the output file
## name will be constructed using the usual \ref filenameGeneration
## routines.

function captain-run-summary {
    local input=reco

    # Check to see if we can find the input file.
    if [ ${#1} != 0 ]; then
	input=${1}
	shift
    elif captain-run-reconstruction; then
	input=reco
    fi 

    # Now check if there are any options
    if [ ${#1} != 0 ]; then
	CAPTAIN_EVENT_LOOP_OPTIONS=${*}
    fi

    captain-run-standard-event-loop captSummary.exe ${input} dst

    CAPTAIN_EVENT_LOOP_OPTIONS=""

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
    if ! which ${1} >> /dev/null; then
	captain-error "The executable ${1} is not available."
    fi
    if [ ${#2} = 0 ]; then 
	captain-error "Must provide a step for the input file."
    fi
    if [ ${#3} = 0 ]; then 
	captain-error "Must provide a step for the output file."
    fi
    local exeFile=$(which ${1})
    local inputFile=$(captain-file ${2})
    local outputFile=$(captain-file ${3})
    captain-log "Run: " $exeFile
    captain-log "Options: " ${CAPTAIN_EVENT_LOOP_OPTIONS}
    captain-log "Input: " ${inputFile}
    captain-log "Output: " ${outputFile}
    if [ ! -f ${inputFile} ]; then
	captain-error "Input file is missing"
	exit 1
    fi
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
	${inputFile} 2>&1 | captain-tee
    captain-log "Completed: " $exeFile
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

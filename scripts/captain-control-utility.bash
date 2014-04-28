#!/bin/bash
#
# This is sourced by the captain-control.bash file.
#

## \page captainControlUtility Utilities for use in captain-control scripts.
##
## This definds a set of utilities to simplify the captain control
## scripts.  These include functions to wrap system programs that are
## not standardized between systems (e.g. mktemp, hostname, and others
## not defined by POSIX), as well as log, warning and error message
## utilities.

## \section systemWrappers System Program Wrappers.
##
## The program wrappers provide a set of standard ways to run system
## programs.  In general, the scripts try to stick to P0SIX, but there
## are some crucial programs that are not defined.  This tries to work
## around that.


#######################################################################
## \subsection captain-tee
## \code 
##   captain-tee
## \endcode
##
##
## Copy the standard input to the job log file and print it to the
## standard output.
export CAPTAIN_JOB_LOG=""
captain-tee () {
    if [ ${#CAPTAIN_JOB_LOG} != 0 ]; then
	tee -a ${CAPTAIN_JOB_LOG}
    else
	exit 1
	cat
    fi
}

#######################################################################
## \subsection captain-system
## \code
##   captain-system
## \endcode
##
## Output a string specifying the system type.  On Linux and Darwin
## this is the output of "uname -s".  The returned strings are:
##   * "Linux" -- For most linux systems.
##   * "Darwin" -- For OSX systems (i.e. Macs).
captain-system () {
    uname -s
}

#######################################################################
## \subsection captain-tempfile
## \code
##   captain-tempfile <prefix>
## \endcode
## \param
## 
## This is a wrapper around the mktemp command.  The mktemp command
## varies between different systems and is not defined in POSIX, so
## this fixes that.  If the argument is present, then it's used as a a
## prefix.  For the purposes of LINUX, it is formed into
## "prefix.XXXXXXXXX"
captain-tempfile () {
    local template="captain.XXXXXXXXXX";
    if [ ${#1} != 0 ]; then
	template="${1}.XXXXXXXXXX"
    fi
    mktemp ${template}
}

#######################################################################
## \subsection captain-hash
## \code
##   captain-hash 
## \endcode
## \param
## 
## This is a wrapper around the sha1sum (or similar) command.  It
## expects to be used as a pipe with the input comming on stdin, and
## printing the hash value to stdout.
captain-hash () {
    if [ -x /usr/bin/sha1sum ]; then
	sha1sum -
	return
    fi
    if [ -x /usr/bin/openssl ]; then
	openssl sha1 | sed 's/.*= *//'
	return
    fi
    echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}

## \section messageOutput Message Output
##
## The captain-log, captain-warning and captain-error functions
## provide a convenient wrapper around the echo command so that
## control script output can be uniformly formatted.  The echo command
## can always be used, but these function should be prefered.  In
## particular, the prefix output lines so they be can be easily found
## in a output log file.

#######################################################################
## \subsection captain-log
## \code
##   captain-log <message>
## \endcode
## \param message  The message to print.
##
## Produce a time stamped log message.  The message can be any text
## string or string of arguments and is handed directly to echo.
## Long messages are line wrapped.
function captain-log {
    local spacer=""
    echo $* | fold -s -w 52 | while read line; do
	echo "%" $(date +"%y-%m-%d %T") "--$spacer $line" | captain-tee
	spacer="  "
    done
}

#######################################################################
## \subsection captain-warning 
## \code
##   captain-warning <message>
## \endcode
## \param message The message to print
##
## Produce a warning message and stack dump.  The warning message can
## be any text string or string of arguments.  They are expanded as
## normal for the shell.  This does not cause the caller to terminate
## or return.  The output is to standard error.
##
function captain-warning {
    local frame=1
    echo "%% xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
	2>&1 | captain-tee >&2
    local spacer=""
    echo "%% WARNING: Warning message at $(date +"%y-%m-%d %T")" \
	2>&1 | captain-tee >&2
    echo $* | fold -s -w 65 | while read line; do
	echo "%% WARNING:${spacer} ${line}" \
	    2>&1 | captain-tee >&2
	spacer="  "
    done
    while caller $frame >> /dev/null; do
	echo "%% WARNING: " $(printf "line %s (%s) in %s" $(caller $frame)) \
	    2>&1 | captain-tee >&2
	((++frame))
    done
    echo "%% xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
	2>&1 | captain-tee >&2
    return
}

#######################################################################
## \subsection captain-error
## \code
##   captain-error <message>
## \endcode
## \param message The message to print
##
##  Produce an error message and stack dump.  The error message can
##  be any text string or string of arguments.  The arguments are
##  expanded as normal for the shell.  This will cause the caller
##  to terminate with an "exit 1".
##
function captain-error {
    local frame=1
    echo "%% xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
	2>&1 | captain-tee >&2
    echo "%% ERROR: Error message at $(date +"%y-%m-%d %T")" \
	2>&1 | captain-tee >&2
    echo $* | fold -s -w 65 | while read line; do
	echo "%% ERROR:${spacer} ${line}" \
	    2>&1 | captain-tee >&2
	spacer="  "
    done
    while caller $frame >> /dev/null; do
	echo "%% ERROR: " $(printf "line %s (%s) in %s" $(caller $frame)) \
	    2>&1 | captain-tee >&2
	((++frame))
    done
    echo "%% xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
	2>&1 | captain-tee >&2
    exit 1
}

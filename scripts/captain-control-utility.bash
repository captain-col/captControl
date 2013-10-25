## \page messageOutputPage Standard log and error output
##
## The captain-log, captain-warning and captain-error family of functions.

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
	echo "%" $(date +"%y-%m-%d %T") "--$spacer $line"
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
    echo "%% xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" >&2
    local spacer=""
    echo "%% WARNING: Warning message at $(date +"%y-%m-%d %T")"
    echo $* | fold -s -w 65 | while read line; do
	echo "%% WARNING:${spacer} ${line}" >&2
	spacer="  "
    done
    while caller $frame >> /dev/null; do
	echo "%% WARNING: " $(printf "line %s (%s) in %s" $(caller $frame)) >&2
	((++frame))
    done
    echo "%% xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" >&2
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
    echo "%% xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" >&2
    echo "%% ERROR: Error message at $(date +"%y-%m-%d %T")"
    echo $* | fold -s -w 65 | while read line; do
	echo "%% ERROR:${spacer} ${line}" >&2
	spacer="  "
    done
    while caller $frame >> /dev/null; do
	echo "%% ERROR: " $(printf "line %s (%s) in %s" $(caller $frame)) >&2
	((++frame))
    done
    echo "%% xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" >&2
    exit 1
}

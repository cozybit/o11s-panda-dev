#!/bin/bash

# Author: Tasos Latsas

# spinner.sh
#
# Display an awesome 'spinner' while running your long shell commands
#
# Do *NOT* call _spinner function directly.
# Use {start,stop}_spinner wrapper functions

# usage:
#   1. source this script in your's
#   2. start the spinner:
#       start_spinner [display-message-here]
#   3. run your command
#   4. stop the spinner:
#       stop_spinner [your command's exit status]
#
# Also see: test.sh

_MSG_ON_SUCC="DONE"
_MSG_ON_FAIL="FAIL"
_C_WHITE="\e[1;37m"
_C_GREEN="\e[1;32m"
_C_RED="\e[1;31m"
_C_RESET="\e[0m"

start_spinner()
{
    #local pid=$1
    local msg=$1
    local delay=0.25
    local spinstr='|/-\'
    #local VERBOSE=1
    echo -n ">>> $msg "
    #while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    #    local temp=${spinstr#?}
    #    [[ -n $VERBOSE ]] || printf "[%c]  " "$spinstr"
    #    local spinstr=$temp${spinstr%"$temp"}
    #    sleep $delay
    #    [[ -n $VERBOSE ]] || printf "\b\b\b\b\b"
    #done
    #[[ -n $VERBOSE ]] || printf "    \b\b\b\b"
    echo
}

stop_spinner()
{
    if [[ $1 -ne 0 ]]; then
        die $2
    fi
}

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

trap 'stop_spinner 0' EXIT
trap 'stop_spinner 1 interrupted' INT

_MSG_ON_SUCC="DONE"
_MSG_ON_FAIL="FAIL"
_C_WHITE="\e[1;37m"
_C_GREEN="\e[1;32m"
_C_RED="\e[1;31m"
_C_RESET="\e[0m"

function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    case $1 in
        start)
            # calculate the column where spinner and status msg will be displayed
            let column=$(tput cols)-${#2}-8
            # display message and position the cursor in $column column
            echo -ne ${2}
            printf "%${column}s"

            # start spinner
            i=1
            sp='\|/-'
            delay=0.15

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                #echo "spinner is not running.."
                return 1
            fi

            kill $3 > /dev/null 2>&1

            # inform the user uppon success or failure
            echo -en "\b["
            if [[ $2 -eq 0 ]]; then
                echo -en "${_C_GREEN}${_MSG_ON_SUCC}${_C_RESET}"
            else
                echo -en "${_C_RED}${_MSG_ON_FAIL}${_C_RESET}"
            fi
            echo -ne "]"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            return 1
            ;;
    esac
}

function start_spinner {
    if [ -n "$VERBOSE" ]; then
        echo -en "\b>>> "
        echo $1
        return 0
    fi
    # $1 : msg to display
    _spinner "start" "${1}" &
    # set global spinner pid
    _sp_pid=$!
    disown
}

function stop_spinner {

    local exit_code=$1
    shift

    local msg=${@}

    if [ -n "$VERBOSE" ]; then

        echo -en "\b["
        if [[ $exit_code -ne 0 ]]; then
            echo -ne "${_C_RED}${_MSG_ON_FAIL}${_C_RESET}"
        else
            echo -ne "${_C_GREEN}${_MSG_ON_SUCC}${_C_RESET}"
        fi
        echo -en "] "

    else
        # $1 : command exit status
        _spinner "stop" $exit_code $_sp_pid
        unset _sp_pid
    fi

    if [[ $exit_code -ne 0 ]]; then
        echo " $msg"
        exit $?
    fi

    echo

    return $exit_code
}


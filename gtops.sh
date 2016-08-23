#!/bin/bash

usage(){
	cat<<EOF
Usage:
	-c		Number of times to run the given command
	--failed-count	Number of allowed failed command invocation attempts before timing out
	--net-trace		For each failed execution, create a 'pcap' file with the network traffic during the execution
	--sys-trace		For each failed execution, create a log for each of the following values, measured during command execution:
					disk I/O, memory, processes/threads, cpu usage of the command, network card package counters
	--call-trace	For each failed execution, add a log with all the system calls ran by the command
	--log-trace		For each failed execution, add also the command output logs (stdout, stderr)
	--debug			Debug mode, show each instruction executed by the script
EOF
}

#Base vars
COUNT=0
FAILEDCNT=0
NET_TRACE=false
SYS_TRACE=false
CALL_TRACE=false
LOG_TRACE=false
DEBUG=false

#Command
COM=$1
shift

#Set TENO wuth getiot parameters
ARGS=`getopt -o c: --long failed-count:,net-trace,sys-trace,call-trace,log-trace,debug -- "$@"`
eval set -- "$ARGS"
# extract options and their arguments into variables.
while true ; do
	case $1 in
	-c) #Check if the given input has a numeric value
		if ! [[ "$2" =~ ^[0-9]*$ ]]; then
			#If not, show the usage instructions, and exit with error			
			usage
			exit 1
		else #If so, initialize the COUNT as the value
			COUNT=$2
		fi
		
		shift 2
		;;

	--failed-count)
		FAILEDCNT=$2
		shift 2
		;;
	
	--net-trace)
		NET_TRACE=true
		shift
		;;

	--sys-trace)
		SYS_TRACE=true
		shift
		;;

	--call-trace)
		CALL_TRACE=true
		shift
		;;

	--log-trace)
		LOG_TRACE=true
		shift
		;;

	--debug)
		DEBUG=true
		shift
		;;

	--)
		shift
		break
		;;
	esac
done

if "$DEBUG"; then
    echo "Arguments: "
	echo -e "COUNT:\t\t"$COUNT
	echo -e "FAILED COUNT:\t"$FAILEDCNT
	echo -e "NET TRACE:\t"$NET_TRACE
	echo -e "SYS TRACE:\t"$SYS_TRACE
	echo -e "CALL TRACE:\t"$CALL_TRACE
	echo -e "LOG TRACE:\t"$LOG_TRACE
	echo -e "DEBUG:\t\t"$DEBUG
fi

#Execute the given command C times

for (( i=1; i<=$COUNT; i++ )){
	if $DEBUG; then
	    echo "[DEBUG] $i outOf $COUNT. Exec: $COM"
	fi
}

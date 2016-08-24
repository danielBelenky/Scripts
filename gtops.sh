#!/bin/bash

function usage(){
	cat<<EOF
Usage:
./daniel.sh <command to wrap> -arg <num of args to pass the wrapped command> <arg1> .. <arg2> .. <argN> <main args (-c --failed-count and etc...)>

Example: ./daniel.sh netstat -arg 1 -a -c 3 --net-trace --debug

        -h              Help
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

function onExit(){
	echo ""
	echo "Terminating..."
	echo "Run finished... printing summary:"
	echo "Most common return code: "$exStat
	exit
}

trap onExit SIGINT SIGTERM

_DEBUG="off"

#Base vars
COUNT=0
FAILEDCNT=0
NET_TRACE=false
SYS_TRACE=false
CALL_TRACE=false
LOG_TRACE=false
DEBUG=false


#Command and its args
COM=$1
shift
#Set TENO wuth getiot parameters
ARGS=`getopt -o c:h --long failed-count:,net-trace,sys-trace,call-trace,log-trace,debug -- "$@"`
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
	-h)
		usage
		break
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
	        set -x
		DEBUG=true
		shift
		;;
	--)
		shift
		break
		;;

	esac
done
#Commented out. Exists just for debugging
#sleep 30

#Execute the given command C times
exStat=0 #Var to hold the exit status
for (( i=1; i<=$COUNT; i++ )){
	eval $COM &> /dev/null #Suppress command's stderr and stdout

	#Wait for the proccess/command to finish before continue
	waitForMe=$(ps -e | grep $COM | awk '{ print $1 }')
	wait $waitForMe

	if (( $? != 0 )); then
		((exStat++)) #Returned 1
	else
		((exStat--)) #Returned 0
	fi
	#Redirect the output of the command to /dev/null, and also it's stdout, stderr
}

if (( exStat < 1)); then
	((exStat=0)) #We had more successful exits
else
	((exStat=1)) #We had more exits with error
fi

echo "Run finished OK... printing summary:"
echo "Most common return code: "$exStat

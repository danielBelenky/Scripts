#!/bin/bash

function usage(){
	cat<<EOF
Usage:
=====
./daniel.sh <command to wrap> <arg1> .. <arg2> .. <argN>

# If your command have its own arguments, then use " ". Example:
./daniel.sh "ping -c 3 google.com" ...

Example: ./daniel.sh COMMAND/APPLICATION -c 3 --net-trace --debug

ALL AVAILABLE ARGUMENTS:
=======================
V       -h              Help
V	-c		Number of times to run the given command [Default is 1]
V	--failed-count	Number of allowed failed command invocation attempts before timing out
V	--net-trace	For each failed execution, create a 'pcap' file with the network traffic during the execution
	--sys-trace	For each failed execution, create a log for each of the following values, measured during command execution:
			disk I/O, memory, processes/threads, cpu usage of the command, network card package counters
V	--call-trace	For each failed execution, save a log with call system calls ran by the command.
V	--debug		Debug mode, show each instruction executed by the script

Please note that some features may require root permissions.
EOF
exit
}

_DEBUG="off"

#Base vars
COUNT=1
FAILEDCNT=0
NET_TRACE=false
SYS_TRACE=false
CALL_TRACE=false
LOG_TRACE=false
DEBUG=false


function cleaner(){
#Make sure no running processes left behind.
	if $SYS_TRACE; then
		kill $KILLIO > /dev/null 2>&1
		kill $KILLPS > /dev/null 2>&1
	fi

	if $NET_TRACE; then
		sudo kill $TCID > /dev/null 2>&1
	fi
}

function onExit(){
	if (( ${failsArray[0]} < ${failsArray[1]} )); then
		FAILS=1
	elif (( ${failsArray[1]} < ${failsArray[0]} )); then
		FAILS=0
	else
		FAILS="Both are the same"
	fi

	cleaner

	echo "Run finished... printing summary:"
	echo "Exited with 1: ${failsArray[1]}"
	echo "Exited with 0: ${failsArray[0]}"
	echo "Most common return code: $FAILS"
	exit 0
}


function TEST(){
	if (( $1==0 )); then
		((failsArray[0]++))
	else
		((failsArray[1]++))
		if $LOG_TRACE && ! $CALL_TRACE; then #Output to log
			echo $2 >> stdout.$LogNameDate.$i.log
		fi
	fi
}

trap onExit SIGINT SIGTERM

#Command and its args
COM=$1

if [ "$COM" == "-h" ]; then
	usage
fi

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
			echo "-c must have a value"			
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
		#Check if the given input has a numeric value
		if ! [[ "$2" =~ ^[0-9]*$ ]]; then
			#If not, show the usage instructions, and exit with error			
			usage
			exit 1
		else #If so, initialize the allowed fails, and set the counter to 0
			FAILEDCNT=$2
			FAILS=0
		fi
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

failsArray=(0 0)
FL=1

#Execute the given command C times
for (( i=1; i<=$COUNT; i++ )){
#Loop to run i times
	trap onExit SIGINT SIGTERM
	#Generate a base name for all the logs
	LogNameDate=`date +%d%m%H%M%S`
	PNAME=$COM	
	TMPFAIL=${failsArray[1]} #Save the current fail status

#Get tcp packages info
	if $NET_TRACE; then
	#Run tcpdump in the background, and supress any nuhup's messages
	#Create a tmp file, which will be deleted if no errors will occur.
		tcpdump -n -w net.$LogNameDate.$i.pcap 2>&1 &
		TCID=$! #Save the ID, to kill it after the given command finishes it's run.
	fi

	if $SYS_TRACE; then
		declare -i PACKETS_BEFORE=`netstat -s | grep packet | head -n1 | grep -o '[0-9]*'`
		free -m | tail -n2 | head -n1 | awk -F" " '{ printf("Memory usage: %s/%s(mb) (%s%% used)\nNow logging the I/O stats:\n", $3, $2, $3*100/$2)  }' > systrace.$LogNameDate.$i.log
		iostat -c 1 -xdc >> systrace.$LogNameDate.$i.log &
		KILLIO=$!
		{
			while true; do
				echo "UID        PID  PPID   LWP  C NLWP STIME TTY          TIME CMD" >> systrace.$LogNameDate.$i.log
				ps -eLf | grep $COM >> systrace.$LogNameDate.$i.log
				sleep 1 #Sleep for 1 sec, otherwise the log is too busy
			done
		} &	
		KILLPS=$!
	fi

	if $CALL_TRACE && ! $LOG_TRACE; then
		#For debug only:
			echo "CALL: $CALL_TRACE. LOG: $LOG_TRACE"
		strace -f $COM > kernel.$LogNameDate.$i.log 2>&1
		TEST $?
	elif $CALL_TRACE && $LOG_TRACE; then
		strace -f $COM 2> kernel.$LogNameDate.$i.log 1> stdout.$LogNameDate.$i
		TEST $?
	else
		OUTPUT=`eval $COM 2>&1`
		COMSTAT=$?
		if [ $COMSTAT -eq 1 ]; then
			TEST 1 "$OUTPUT"
		else
			TEST 0
		fi
	fi
	
	if $SYS_TRACE; then
		declare -i PACKETS_AFTER=`netstat -s | grep packet | head -n1 | grep -o '[0-9]*'`
		declare -i TOTAL_IP_PACKETS=${PACKETS_AFTER}-${PACKETS_BEFORE}	
		printf "\nTotal Network packages sent during the exec: $TOTAL_IP_PACKETS" >> systrace.$LogNameDate.$i.log 
	fi
	
	if (( $TMPFAIL==${failsArray[1]} )); then #We had successes
		if $NET_TRACE; then #Remove the tmp cap file generated by the tcpdump
			sudo rm net.$LogNameDate.$i.pcap > /dev/null 2>&1
		fi	
	fi	
	
	cleaner

	if (( $FAILEDCNT!=0 && ${failsArray[1]}==$FAILEDCNT )); then
		#Check if --failed-count was initialized
		echo "Reached maximum allowed fails [${failsArray[1]}] aborting..."
		onExit
	fi	
} #End of for loop

onExit

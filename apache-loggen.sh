#!/bin/bash

#
# Functions
#

write_output() {

	if [ "$1" = "nc" ]
	then
		cmd="nc $SERVER_IP $SERVER_PORT"
	elif [ "$1" = "console" ]
	then
		cmd="cat"
	else
		echo "Unknown output channel $1"
		return 1
	fi

	let i=1
	let total_events=0

	tstart_ms=$(($(date +%s%N)/1000000))
	for ((j=0 ; j<$ITERATIONS; j++))
	do
		cat $APACHE_LOG
	done | while read line
  do
		DATE=`date "+%d/%b/%Y:%H:%M:%S %z"`
		echo $line | sed -e 's@\[\(.*\)\]@['"$DATE"']@'
		let total_events=total_events+1
		if (( "$NO_OF_EVENT" != 0 && "$NO_OF_EVENT" <= total_events ))
		then
				echo "Done generating $NO_OF_EVENT events, returning." 1>&2
				return
		fi
		if (( "$COUNT" == i ))
		then
			#echo "Sleeping one second before emitting more messages"
	    tnow_ms=$(($(date +%s%N)/1000000))
			tdiff=$(($tnow_ms-$tstart_ms))
			if [ $tdiff -lt 1000 ]
			then
				tdiff=$((1000 - $tdiff))
				echo "Waiting for $tdiff milliseconds" 1>&2
				wait_time=$(echo "$tdiff/1000" | bc -l)
				sleep $wait_time
			else
				echo "Took more than $tdiff milliseconds to replay $COUNT messages, skipping sleep" 1>&2
			fi
			tstart_ms=$(($(date +%s%N)/1000000))
			i=1
		else
			let i=i+1
		fi
	done  | $cmd

}

#
# Usage instructions
#
usage() {
    cat << ENDUSAGE

    Usage: $0 -l apache_logfile -c log_per_second [ -o nc ] [-p server_port -s server_ip] [-i x] [-h]
    -l : Apache log file
    -i : no. of times to replay given log file, default 1
    -c : no. of messages to emit per second
    -o : output channel, nc or console, default is console
    -p : server port, if you want to send over nc
    -s : server ip, if you want to send over nc
    -n : generate n events and then exit
    -h : show me this help

ENDUSAGE
        exit 0
}

###################
# The main script
###################
APACHE_LOG=
COUNT=1
SERVER_PORT=
OUTPUT="console"
ITERATIONS=1
NO_OF_EVENT=0

while getopts "l:c:i:n:o:p:s:h" options; do
  case $options in
    c ) COUNT=$OPTARG;;
    l ) APACHE_LOG=$OPTARG;;
    i ) ITERATIONS=$OPTARG;;
    n ) NO_OF_EVENT=$OPTARG;;
    o ) OUTPUT=$OPTARG;;
    p ) SERVER_PORT=$OPTARG;;
    s ) SERVER_IP=$OPTARG;;
    h ) usage;;
  esac
done

if [ "X$APACHE_LOG" = "X" ]; then
    echo "The apache log conf file must be given through the -l parameter."
    usage
    exit 1
fi

if [ "$OUTPUT" = "nc" ]; then
	if [ "X$SERVER_IP" = "X" ]; then
		echo "Server ip not specified."
		usage
		exit 1
	fi
	if [ "X$SERVER_PORT" = "X" ]; then
		echo "Server port not specified."
		usage
		exit 1
	fi
fi

write_output $OUTPUT

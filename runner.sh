#!/bin/bash

#****************************************************************************************************************\
#                                                                                                                *
#  Script Name     :  runner.sh                                                                                  *
#                                                                                                                *
#  Purpose         :  Get an input command and optional flags , and print a summary of the command executions    *
#                     that include return-codes summary                                                          *
#                                                                                                                *
#  Inputs          :  Command for executions                                                                     *
#                     Number of times to run the command                                                         *
#                                                                                                                *
#  Optional flags  :  Number of allowed failed command invocation                                                *
#                     creating network traffic capture - for failed execution                                    *
#                     crating system/resources metrics measured during command execution - for failed execution  *
#                     creating log for all system calls ran by the command - for failed execution                *
#                     creating command output logs (stdout , stderr) - for failed execution                      *
#                     Running with debug mode that show each instruction executed by the script                  *
#                                                                                                                *
#                                                                                                                *
#                                                                                                                *
#  Written by      :  Mohamad Abo-Ras (mohamad.abo.ras@gmail.com)                                                *
#                                                                                                                *
#  Date : 01Jan 2018                                                                                             *
#                                                                                                                *
# Changes History:                                                                                               *
#                                                                                                                *
#     Date    |     By     |  Changes/New features                                                               *
# ----------+------------+----------------------------------------------- *                                      *
#  01.01.2018 |  Mohamad   | script created for 1st version .             *                                      *
#           8 |  Abo-Ras   |                                              *                                      *
# ----------+------------+----------------------------------------------- *                                      *
#****************************************************************************************************************/




## define global variables
export DEBUG="set +x"                          ## disabled debug
export execution_count=0                       ## total executions counter
export DEFAULT_EXIT_CODE=255                   ## default exit-code
export EXEC_NAME=$(basename $0)                ## script name 
export OUTPUT_DIR="`pwd`"                      ## path for output & generated files 
export TIME_SIGNUTURE="date +"%Y%m%d_%H%M%S""  ## current date&time


## define local functions/methods 

## print the summary report
#  And exit the program with the most frequent return-code .
#  in case no returned-codes (such case if the script killed while the first invocation) , then it will exit with default-return-code (predefined as 255)
finalize() {
    
   frequent_rc=${DEFAULT_EXIT_CODE}
   if [[ ! -z ${list_rc[@]} ]] ; then
      
      printf "|------Return Codes Summary-----|\n"
      printf "|  Return-Code  |  Occurrence   |\n"
      printf "|-------------------------------|\n"
      echo ${list_rc[@]} | tr ' ' '\n' | sort | uniq -c | sort -rnk 1 | awk '{ printf "|\t%2d\t|\t%2d\t|\n", $2, $1 }' 
      printf "|-------------------------------|\n"

      frequent_rc=$(echo ${list_rc[@]} |tr ' ' '\n' | sort | uniq -c | sort -rnk 1 | head -1 | awk '{print $2}')
   fi

   exit ${frequent_rc}

}

## signal handler 
#  catch system signals (SIGINT , SIGTERM) 
# handler : call finalize
# note : trap will not catch SIGKILL signal as OS doesn't allow it 
trap finalize SIGINT SIGTERM



## print script usage 
usage() {

	cat <<EOF
Usage: ${EXEC_NAME} [OPTION].... [command [arg ...]]

  -c COUNT            Number of times to run the given command
  --failed-count N    Number of allowed failed command invocation attempts before giving up
  --net-trace         For each failed execution, create a 'pcap' file with the network traffic during the execution.
  --sys-trace         For each failed execution, create a log for each of the following values, measured during command execution
					(disk io,+memory,processes/threads,cpu usage of the command network card package counters)
  --call-trace        For each failed execution, add also a log with all the system calls ran by the command
  --log-trace         For each failed execution, add also the command output logs (stdout, stderr)
  --debug             Debug mode, show each instruction executed by the script
EOF

	exit ${DEFAULT_EXIT_CODE}
}

# generate network traffic capture by calling to tcpdump
# default : collect 4000 packets for all the network interfaces formatted with default timestamp with extra verbose output 
# note : those values is configurable and could be any value depend on the local machine/server and which details needed to capture from network traffic 
exec_net_trace () {

    export NET_PCAP="${OUTPUT_DIR}/net_trace_`${TIME_SIGNUTURE}`.pcap"
    [[ ${NET_TRACE} ]] && /usr/sbin/tcpdump -i any -vvv -nnN -tttt -s0 -c 4000 -w ${NET_PCAP}
	
}



# generate system/resources metrics measured by using OPVA-HP extract utility : disk io , memory , processes/threads and cpu usage of the command,network card package counters
# time frame to generate from start to end date with format : %m/%d/%Y %H:%M:%S" , e.g. 01/01/2018 12:15:00
# all the extracted data saved to common file "SYS_TRACE_OUT"
#  + alternative utility is to use named sar "/usr/bin/sar"  - Collect, report, or save system activity information
#      time-frame(start to end) time format is "HH:MM:SS"
#      example : sar -n ALL -P ALL -r -u  -s ${START_TIME} -e ${END_TIME}
exec_sys_trace() {
  
    export SYS_TRACE_OUT="${OUTPUT_DIR}/sys_trace_`${TIME_SIGNUTURE}`.out"
    [[ ${SYS_TRACE} ]] && /opt/perf/bin/extract -GDNUY -xp -b \"${START_DATE}\" -e \"${END_DATE}\"  -f ${SYS_TRACE_OUT}
	
}







#************************************************************************************************************
#                                                                                                           *
#                    m a i n                    p r o g r a m                    f l o w                    *
#                                                                                                           *
#************************************************************************************************************






# Test getopt : run getopt for test , if fail then exit 
getopt --test > /dev/null
if [[ $? -ne 4 ]]; then
    echo "getopt Test :  `getopt --test` failed in this environment."
    exit ${DEFAULT_EXIT_CODE}
fi




# setting the valid options : short&long options
# -c => mandatory flag & input argument required
# --failed-count => optional flag & input argument required
# --net-trace => optional flag & input argument not required
# --sys-trace => .... same as previous
# --call-trace => .... same as previous
# --log-trace => .... same as previous
# --debug  => .... same as previous
SHORT_OPTIONS=c:
LONG_OPTIONS=failed-count:,net-trace,sys-trace,call-trace,log-trace,debug

OPTS=$(getopt --options=${SHORT_OPTIONS} --longoptions=${LONG_OPTIONS} --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
    # e.g. $? == 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi


# read getopt's output this way to handle the quoting right:
eval set -- "${OPTS}"



# parse each options from argument list until getting separate --
while true; do
    case "$1" in
	
	    -c)
	    # Getting & store the execution count/times
            export COUNT="$2"
            shift 2
            ;;
			
        --failed-count)
            # Getting & store the failed execution count
            export FAIL_COUNT="$2"
            shift 2
            ;;
			
        --debug)
	    # Setting the debug options
            export DEBUG="set -xvf"
            shift
            ;;
			
        --net-trace)
	    # trigger tcpdump to generate network traffic : we used - /usr/sbin/tcpdump
            export NET_TRACE="Y"
            shift
            ;;
        --sys-trace)
	    # triggering OPVA Extract  utility to generate system resources measured matrices : we used /opt/perf/bin/extract
            export SYS_TRACE="Y"
            shift
            ;;
			
        --call-trace)
	    # trigger the strace to generate call trace - we used /usr/bin/strace 
            export CALL_TRACE="Y"
            shift
            ;;
			
        --log-trace)
	    # trigger the log trace by printing the stdout & stderr to separate log files 
            export LOG_TRACE="Y"
            export LOG_OUT="${OUTPUT_DIR}/log_trace_`${TIME_SIGNUTURE}`.out"
            export LOG_ERR="${OUTPUT_DIR}/log_trace_`${TIME_SIGNUTURE}`.err"
            shift
            ;;


        --)
		# once we arrived to -- this end of arguments parsing 
            shift
            break
            ;;
        *)
		# when the input from OPTS no matching any of above , then it means the input not valid/or something wrong happened 
            usage
            ;;
    esac
done


# enable/disable the debug option depend on the input options (if --debug was passed)
${DEBUG}




# handle non-option arguments , check if the input argument(not for the OPTS) mount is only 1 argument(one argument for the command parameter)
if [[ $# -ne 1 ]]; then
    usage
fi


# getting the command to run from command-line argument 
COMMAND="$1"

# declare array to store all the returned value for each command execution
set -a list_rc







# command executions loop - main invocations steps 
# Test and check the executions time and allowed fails counters 
while [[ ${execution_count} != ${COUNT} ]] && [[ ${failed_executions} != ${FAIL_COUNT} ]] ; do

      export START_DATE=$(date +"%m/%d/%Y %H:%M:%S")
      export CALL_TRACE_OUT="${OUTPUT_DIR}/call_trace_`${TIME_SIGNUTURE}`.out"


       # if --net-trace enabled then trigger net traffic monitor
       [[ ${NET_TRACE} ]] && exec_net_trace  1>/dev/null 2>&1  & 
       wait_pids="${wait_pids} $!"



      # --log-trace enable 
      if [[ ${LOG_TRACE} ]] ; then 
                                  
          # --call-trace
          if  [[ ${CALL_TRACE} ]] ; then 
                  
                  /usr/bin/strace -ttT -o ${CALL_TRACE_OUT} ${COMMAND} 1>>${LOG_OUT}  2>>${LOG_ERR} 
                  
                  # getting return code from strace.out file 'exit_group' printted in the last line in strace.out and include exit-code exit_group(exit-code)
                  this_rc="`grep exit_group ${CALL_TRACE_OUT} | tail -1 | cut -d'(' -f2 | cut -d')' -f1`"


          else
                   # redirect the stdout & stderr to separate file in filesystem
                   ${COMMAND} 1>>${LOG_OUT}  2>>${LOG_ERR}
            
                   this_rc=$?
          fi
      
      else
          # --call-trace
          if  [[ ${CALL_TRACE} ]] ; then

                  /usr/bin/strace -ttT -o ${CALL_TRACE_OUT} ${COMMAND}
                  this_rc="`grep exit_group ${CALL_TRACE_OUT} | tail -1 | cut -d'(' -f2 | cut -d')' -f1`"


          else
                   ${COMMAND}
                   this_rc=$?
          fi
   
      

      fi
      

      wait ${wait_pids}

      export END_DATE=$(date +"%m/%d/%Y %H:%M:%S")


      # save the returned-code of the command execution into the list
      list_rc[execution_count]=${this_rc}

      # return-code handler in two cases success/fail
      # failure case : increase the failed execution counter to be updated for the next execution in while loop
      # success case : delete the pcap file that the generated only if net-trace is enabled
      [[ ${this_rc} != 0 ]] && ((failed_executions++))
      [[ ${this_rc} == 0 ]] &&  [[ ${NET_TRACE} ]] && rm -f ${NET_PCAP}
     
      # update the loop counter in any case 
      ((execution_count++))

      # another case : if the execution failed - then trigger the sys-trace generation 
      [[ ${this_rc} != 0 ]] && exec_sys_trace 1>/dev/null 2>&1 
          
done


# calling to finalize to print the summary , when the script done
finalize

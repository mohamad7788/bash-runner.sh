# bash-runner.sh


The Task
========
Task description :  Bash script called 'runner.sh' that wraps any other command and outputs a summary of execution, similar to the ping command, with the following options:

						-c COUNT - Number of times to run the given command
						--failed-count N - Number of allowed failed command invocation attempts before giving up
						--net-trace - For each failed execution, create a ‘pcap’ file with the network traffic during the execution.
						--sys-trace - For each failed execution, create a log for each of the following values, measured during command execution:
							+ disk io
							+ memory
							+ processes/threads and cpu usage of the command
							+ network card package counters
						--call-trace - For each failed execution, add also a log with all the system calls ran by the command
						--log-trace - For each failed execution, add also the command output logs (stdout, stderr)
						--debug - Debug mode, show each instruction executed by the script


	Basic functionality :-
	---------------------
				- print a summary of the command return codes (how many times each return code happened).
				- even if/when the script was interrupted (via ctrl+c or 'kill')
				- return the most frequent return code when exiting


	Implemented functions :-
	------------------------
				+ functional options :
	   				   -c COUNT
					     --failed-count N 
				+non-functional options :
					   --net-trace 
					   --sys-trace
					   --call-trace
					   --log-trace
					   --debug
   
	
Design & Development Process
============================

			1) basic requirement 
					1.1) run any simple command by command-line 
					1.2) think about different cases : command execution fail , command execution success 
					1.3) look into the returned-code in each case 
					1.4) running a command n times in a loop and do the same previous steps (1.1-1.3)
					
					OS interrupts : trap & catch system signals , Get more info about "Linux Trap" ,  
          OS System process signals , and process management(stackOverFlow,LDAP,internet Online references & examples)

					1.5) create a simple function/method that do some echo
					1.6) create your own trap to catch "ctrl+c" , and see the behaviour in the same Linux shell
					1.7) test the all scenarios & cases to make sure that's functioning based on the OS Trap documentation & examples 

					**Note : Unix system by design doesn't allow any script/program to trap SIGKILL due to security reasons . 
					
					++ frequent returned-codes : think about some simple commands that do this target like :-
                    sorting , uniq , counting etc,...
					
					++ command options/flags : in this current step , we need to look into the basic flags (count & failed allowed)
						a) try to look for "bash options  getopt" 
						b) read a simple examples , then try it in different shell/script till it work
						c) Think about how to combine the count's flags into the working example
							in case you get any error , try to search for the reason , and read the related explanation . 
						
					
					Now we are ready to implement the basic requirement .
					
					in this step , you need to develop one script that include all of the above requirement , 
                    once it done - try to read and think about the code you wrote , 
                    and try to cover the all cases before the first execution . 

					First execution :-  
          run the script , in case you face any syntax error then fix it before you start think about the possible cases .
					Hint : write a test-commands file , that include different commands that return randome return-code 
          (this will be the input for the final script)
						
						$ cat test_command.sh 
						#!/bin/bash
						
						ret="`echo $RANDOM % 3 | bc`"
						echo "sleep ${ret}sec"
						ls $ret
						sleep ${ret}
						exit   ${ret}



					
						i) running the script with all the needed inputs 
						$ ./runner.sh -c 5 --failed-count 2 test_command.sh
						sleep 0sec
						ls: 0: No such file or directory
						sleep 1sec
						ls: 1: No such file or directory
						sleep 0sec
						ls: 0: No such file or directory
						sleep 0sec
						ls: 0: No such file or directory
						sleep 2sec
						ls: 2: No such file or directory
						|------Return Codes Summary-----|
						|  Return-Code  |  Occurrence   |
						|-------------------------------|
						|	 0	|	 3	|
						|	 2	|	 1	|
						|	 1	|	 1	|
						|-------------------------------|
						 

						then you need to verify the Returned code of the main script is equal the same RC with high occurrence
						note $? is returned-code of the last command , so you need to run it immediately to get the RC of the main script  
						$ echo $?
						0

						
					
						ii) create a usage/help summary to be printed when the input isn't valid
						
						$ ./runner.sh -c 5 --failed-count 2                
						Usage: runner.sh [OPTION].... [command [arg ...]]
						
						-c COUNT            Number of times to run the given command
						--failed-count N    Number of allowed failed command invocation attempts before giving up
						--net-trace         For each failed execution, create a 'pcap' file with the network traffic during the execution.
						--sys-trace         For each failed execution, create a log for each of the following values, measured during command execution .
						--call-trace        For each failed execution, add also a log with all the system calls ran by the command
						--log-trace         For each failed execution, add also the command output logs (stdout, stderr)
						--debug             Debug mode, show each instruction executed by the script
						
						

						
		 2)develop all the available options :-
						
						debug             
        ------------------
          Debug mode, show each instruction executed by the script										     
          The point here is to enable debug into the main script , as it's ued in Linux to print 
											
					$ bash -x runner.sh : this will trace everything exeuted by the script from command-line

					control the debug into code by using : set +/- x 
					as enabling debug by : set -x 
					as disabling debug by : set +x

					in this task , we set a default debug to be disabled , 
					export DEBUG="set +x"                          ## disabled debug
											 
					And it changed in the getopts(when --debug passed to the script) , 
											 
					--debug)
					  	 # enable the debug options
						   export DEBUG="set -x"
							 shift
							 ;;
										
					Trigger debug mode : executing set +/-x  by ${DEBUG} immediately after parsing the options 
											
											# enable/disable the debug option depend on the input options (if --debug was passed)
											${DEBUG}
											 
						




						log-trace  
        --------------------
            For each failed execution, add also the command output logs (stdout, stderr) , 
	          checking the options while parse opts in getopt 
											
											        --log-trace)
													 # trigger the log trace by printing the stdout & stderr to separate log files 
													 export LOG_TRACE="Y"
													 export LOG_OUT="${OUTPUT_DIR}/log_trace_`${TIME_SIGNUTURE}`.out"
													 export LOG_ERR="${OUTPUT_DIR}/log_trace_`${TIME_SIGNUTURE}`.err"
													 shift
													 ;;
											
						Holding a flag to determine that the log-trace enabled , also define two files name with timestamp , 
            the standard output/errors of the command will be redirected to those files  
						LOG_OUT - for the standard outputs , LOG_ERR for the standard errors 
											
											
						Trigger the log-trace : when executing the command and to redirect the command outputs to those files 
											
											# redirect the stdout & stderr to separate file in filesystem
											${COMMAND} 1>>${LOG_OUT}  2>>${LOG_ERR}

						
						
          sys-trace       
     ---------------------
            For each failed execution, create a log for each of the following values, measured during command execution:-
            
            --sys-trace)
              # triggering OPVA Extract  utility to generate system resources measured matrices : we used /opt/perf/bin/extract
              export SYS_TRACE="Y"
              shift
              ;;
						
            
            as the extract tool extract a data based on times so we saved start & end time  for each command execution .
											
											
						Trigger sys trace : checking the returned code of the executed command , and in case failed (return-code not zero) 
            then calling to the below function :
											
											exec_sys_trace() {
											
												export SYS_TRACE_OUT="${OUTPUT_DIR}/sys_trace_`${TIME_SIGNUTURE}`.out"
												[[ ${SYS_TRACE} ]] && /opt/perf/bin/extract -GDNUY -xp -b \"${START_DATE}\" -e \"${END_DATE}\"  -f ${SYS_TRACE_OUT}
											
											}
											
						then it will extract system resources values during the execution by start & end date :-
											
											# another case : if the execution failed - then trigger the sys-trace generation 
											[[ ${this_rc} != 0 ]] && exec_sys_trace 1>/dev/null 2>&1

													
												
							
												
						
						call-trace        
      -----------------------
      For each failed execution, add also a log with all the system calls ran by the command
      searching for "bash system calls" - http://www.tldp.org/LDP/lkmpg/2.4/html/x939.html
			parsing the options by getops and check if the flag --call-trace passed to the script input argument 

											        --call-trace)
														      # trigger the strace to generate call trace - we used /usr/bin/strace 
														       export CALL_TRACE="Y"
														       shift
														       ;;

						
						
					
						net-trace         
     ----------------------------
            For each failed execution, create a 'pcap' file with the network traffic during the execution.
						The implementation here isn't easy  , as it designed to capture the network traffic with 4000 packet (with background process) before execute the command 
             runner.sh ->  run tcpdump in background -->  execute the command ---> wait till tcpdump done & contiune with the next 
												 
												 
                                                 # command executions loop - main invocations steps 
                                                 # Test and check the executions time and allowed fails counters 
                                                 while [[ ${execution_count} != ${COUNT} ]] && [[ ${failed_executions} != ${FAIL_COUNT} ]] ; do
                                                 
                                                       export START_DATE=$(date +"%m/%d/%Y %H:%M:%S")
                                                       export CALL_TRACE_OUT="${OUTPUT_DIR}/call_trace_`${TIME_SIGNUTURE}`.out"
                                                 
                                                 
                                                        # if --net-trace enabled then trigger net traffic monitor
                                                        [[ ${NET_TRACE} ]] && exec_net_trace  1>/dev/null 2>&1  &
                                                        wait_pids="${wait_pids} $!"
												 
            and waiting to the tcpdump process to finish before flipping next execution by using "wait" :-

			      								wait ${wait_pids}
														export END_DATE=$(date +"%m/%d/%Y %H:%M:%S")
												 

												 
												 
Top important topics 
====================
		+ getopt/getopts
		+ trap & system signals
		+ net-trace : by using /usr/sbin/tcpdump
		+ syst-trace : by vmstat & OPVA-HP extract tool 
		+ call-trace : by using /usr/bin/strace
		
Materials , Appendix 
====================

    - stackoverflow : searched for
	  - TLDP(The Linux Documentation Project) : http://tldp.org/guides.html
	  - github : 

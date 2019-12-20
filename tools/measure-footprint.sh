#!/bin/bash

collect_time=10
interval=1
profile_mode=""
app_process_id=""
footprint_datafile="$$.fp.data"
verbose_mode=0

function usage() {
  local pname=`basename $0`
  echo "Usage:"
  echo "$pname [-p pid1,pid2,...] [-t time] [-f] [-v] [-h] [-e \"applicaton <args,...>\"]"
  echo
  echo "  -p pid(s) : application process ids to profile"
  echo "  -t time : time in seconds. Default ${collect_time}s"
  echo "  -i interval: sample interval in seconds. Default {interval}s".
  echo "  -v : Verbose mode"
  echo "  -f : Measure the memory usage/footprint of given processes."
  echo "  -h : Help message"
  echo
  echo "  Examples:"
  echo "  1) Code footprint data for a single process"
  echo "    $ measure-footprint.sh -p 2345"
  echo
  exit
}

command_name=""
while [ "$1" != "" ]; do
  case $1 in
    -p) shift
      app_process_id=$1
      profile_mode="one"
      ;;
    -t) shift
      collect_time=$1
      ;;
    -i) shift
      interval=$1
      ;;
    -v) verbose_mode=1
      ;;
    -f) metric_mode="footprint"
      ;;
    *) usage
      exit 1
  esac
  shift
done

function getValue() {
    local proc_status="/proc/${1}/status"
    if [ -r ${proc_status} ]; then
    local val=`grep "^${2}:" $proc_status | awk '{print $2}' | tr -d '[:space:]'`
    echo $val
    else
	echo 1
    fi
}

function getUnit() {
    local proc_status="/proc/${1}/status"
    if [ -r ${proc_status} ]; then
    local val=`grep "^${2}:" $proc_status | awk '{print $3}'`
    if [ "${val}" == "kB" ]; then
	echo 1024
    else
      echo  1
    fi
    else
	echo 1
    fi
}

function getProcValue() {
    local tU=`getUnit ${1} ${2}`
    local tV=`getValue  ${1} ${2}`
    local lV=`expr ${tV} \* ${tU}`
    echo $lV
}

# Collects memory usage data every 1 second
function collect_memory_usage_data() {
    # cat /proc/$pid/status
    # vmPeak (peak virtual memory sz)
    # vmSize (Virtual memory sz)
    # vmLock (Locked memory sz)
    # vmRss (Resident set size. RssAnon+RssFile+RssShmem)
    #  RssAnon (size of resident anonymous memory)
    #  RssFile (size of resident file mappings)
    #  RssShmem (size of resident shared memory)
    # VmHWM (peak resident size)
    # VmExe (Code/text segment)
    # VmData (size of data)
    # VmLib (shared library code size)
    # VmStk (size of stack usage)
    if [ "x${app_process_id}" == "x" ]; then
      echo "Missing process id"
      return
    fi

    echo "------------------------------------------------------------"
    echo "`date`: Collecting memory usage data in real time for ${collect_time} seconds with sample interval of ${interval} seconds"
    echo "------------------------------------------------------------"    
    local OLDIFS=$IFS
    local realpid=$app_process_id
    IFS=","; read -ra local_pids <<< "${app_process_id}"

    local CodeSize=0
    local SharedLibCode=0
    local ResidentCode=0
    local PeakResidentSize=0
    local ProcessData=0
    local ProcessStack=0
    local RssAnon=0
    local RssFile=0
    local RssShmem=0
    local PageTableEntries=0
    local HugetlbPages=0
 
    local samples=0
    local collect_time=`expr ${collect_time} / ${interval}`
    while [ $samples -lt ${collect_time} ]
    do
      for i in "${local_pids[@]}"
      do
	if [ $verbose_mode -eq 1 ]; then
	  echo "Checking if process with pid ${i} exists..."
	fi
		
	if [ ! -r "/proc/${i}" ]; then
            echo "ERROR: Process with PID ${i} is not found."
	    return
	fi

	local v=`getProcValue ${i} VmExe`
	CodeSize=`expr ${CodeSize} + ${v}`

	local lv=`getProcValue  ${i} VmLib`
	SharedLibCode=`expr ${SharedLibCode} + ${lv}`

	local rv=`getProcValue  ${i} VmRSS`
	ResidentCode=`expr ${ResidentCode} + ${rv}`

	local dv=`getProcValue  ${i} VmData`
	ProcessData=`expr ${ProcessData} + ${dv}`

	local sv=`getProcValue  ${i} VmStk`
	ProcessStack=`expr ${ProcessStack} + ${sv}`
	
	if [ $verbose_mode -eq 1 ]; then
	    echo "`date`: Sample[$samples]"
	    echo "Code:${v}, SharedLib:${lv}, ResidentCode:${rv}, Data:${dv}, Stack:${sv}"
            echo "------------------------------------------------------------"
	fi
	
	v=`getProcValue ${i} VmHWM`
	PeakResidentSize=`expr ${PeakResidentSize} + ${v}`	

	v=`getProcValue ${i} RssAnon`
	RssAnon=`expr ${RssAnon} + ${v}`

	v=`getProcValue ${i} RssFile`
	RssFile=`expr ${RssFile} + ${v}`

	v=`getProcValue ${i} RssShmem`
	RssShmem=`expr ${RssShmem} + ${v}`

	
      done
      samples=`expr $samples + 1`
      sleep ${interval}  #Sleep before collecting next set of data
    done
    IFS=$OLDIFS

    echo
    echo "* Footprint data Summary"
    echo "------------------------------------------------------------"
    echo "Number of samples taken: ${samples} at ${interval}s interval"
    echo "------------------------------------------------------------"

    CodeSize=`expr ${CodeSize} / $samples`
    echo "Avg. Code size: ${CodeSize}"
    SharedLibCode=`expr ${SharedLibCode} / $samples`
    echo "Avg. Shared Lib code: ${SharedLibCode}"
    ResidentCode=`expr ${ResidentCode} / $samples`
    echo "Avg. Resident Set : ${ResidentCode}"
    RssAnon=`expr ${RssAnon} / $samples`
    echo "  ...Avg. Resident anonymous memory : ${RssAnon}"    
    RssFile=`expr ${RssFile} / $samples`
    echo "  ...Avg. Resident File mappings : ${RssFile}"
    RssShmem=`expr ${RssShmem} / $samples`
    echo "  ...Avg. Resident shared memory : ${RssShmem}"    
    PeakResidentSize=`expr ${PeakResidentSize} / $samples`
    echo "Avg. Peak Resident Set : ${PeakResidentSize}"

    ProcessData=`expr ${ProcessData} / $samples`
    echo "Avg. Data set: ${ProcessData}"

#    PageTableEntries=`expr ${PageTableEntries} / $samples`
#    echo "Avg. Page table entries:${PageTableEntries}"

#    HugetlbPages=`expr ${HugetlbPages} / $samples`
#    echo "Avg. Huge TLB pages:${HugetlbPages}"

    ProcessStack=`expr ${ProcessStack} / $samples`
    echo "Avg. Stack size:${ProcessStack}"
    echo "------------------------------------------------------------"    
}

collect_memory_usage_data

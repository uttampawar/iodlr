#!/bin/bash -x
SCRIPTS_DIR=`dirname $0`

source ${SCRIPTS_DIR}/utils.sh


function init_itlb_stalls() {
  #Comma seperated perf supported counter names. See example below"
  local local_pmu_array=(instructions icache_64b.iftag_stall itlb_misses.walk_completed itlb_misses.walk_completed_4k itlb_misses.walk_completed_2m_4m)
  for item in ${local_pmu_array[*]}
  do
    if [ "x${local_pmus}" == "x" ]; then
      local_pmus="$item"
    else
      local_pmus="$local_pmus,$item"
    fi
  done
  echo $local_pmus
}

function dis_itlb_stalls() {
  init_itlb_stalls
}

function calc_itlb_misses() {
  local perf_data_file="$1"
  echo
  echo "================================================="
  echo "Final itlb_stalls metric"
  echo "--------------------------------------------------"
  echo "FORMULA: metric_ITLB_Misses(%) = 100*(a/b)"
  echo "         where, a=icache_64b.iftag_stall"
  echo "                b=cycles"
  echo "================================================="

  local a=`return_pmu_value "icache_64b.iftag_stall" ${perf_data_file}`
  local b=`return_pmu_value "cycles" ${perf_data_file}`

  if [ $a == -1 -o $b == -1 ]; then
    echo "ERROR: metric_ITLB_Misses can't be derived. Missing pmus"
  else
    local metric=`echo "scale=$bc_scale;100*(${a}/${b})"| bc -l`
    echo "metric_ITLB_Misses=${metric}"
  fi

}

function calc_itlb_mpki() {
  local perf_data_file="$1"
  echo
  echo "================================================="
  echo "Final itlb_mpki metric"
  echo "--------------------------------------------------"
  echo "FORMULA: metric_ITLB_MPKI(%) = 1000*(a/b)"
  echo "         where, a=itlb_misses.walk_completed"
  echo "                b=instructions"
  echo "================================================="

  local a=`return_pmu_value "itlb_misses.walk_completed" ${perf_data_file}`
  local b=`return_pmu_value "instructions" ${perf_data_file}`
  if [ $a == -1 -o $b == -1 ]; then
    echo "ERROR: metric_ITLB_MPKI can't be derived. Missing pmus"
  else
    local metric=`echo "scale=$bc_scale;1000*(${a}/${b})"| bc -l`
    echo "metric_ITLB_MPKI(%)=${metric}"
  fi
  
}

function calc_itlb_4k_mpki() {
  local perf_data_file="$1"
  echo
  echo "================================================="
  echo "Final itlb_4k_mpki metric"
  echo "--------------------------------------------------"
  echo "FORMULA: metric_ITLB_4K_MPKI(%) = 1000*(a/b)"
  echo "         where, a=itlb_misses.walk_completed_4k"
  echo "                b=instructions"
  echo "================================================="

  local a=`return_pmu_value "itlb_misses.walk_completed_4k" ${perf_data_file}`
  local b=`return_pmu_value "instructions" ${perf_data_file}`
  if [ $a == -1 -o $b == -1 ]; then
    echo "ERROR: metric_ITLB_4K_MPKI can't be derived. Missing pmus"
  else
    local metric=`echo "scale=$bc_scale;1000*(${a}/${b})"| bc -l`
    echo "metric_ITLB_4K_MPKI(%)=${metric}"
  fi
  echo
}

function calc_itlb_2m_4m_mpki() {
  local perf_data_file="$1"
  echo
  echo "================================================="
  echo "Final itlb_2M_4M_mpki metric"
  echo "--------------------------------------------------"
  echo "FORMULA: metric_ITLB_2M_4M_MPKI(%) = 1000*(a/b)"
  echo "         where, a=itlb_misses.walk_completed_2m_4m"
  echo "                b=instructions"
  echo "================================================="

  local a=`return_pmu_value "itlb_misses.walk_completed_2m_4m" ${perf_data_file}`
  local b=`return_pmu_value "instructions" ${perf_data_file}`
  if [ $a == -1 -o $b == -1 ]; then
    echo "ERROR: metric_ITLB_2M_4M_MPKI can't be derived. Missing pmus"
  else
    local metric=`echo "scale=$bc_scale;1000*(${a}/${b})"| bc -l`
    echo "metric_ITLB_2M_4M_MPKI(%)=${metric}"
  fi
  echo
}

function calc_itlb_stalls() {
  local perf_data_file="$1"
  calc_itlb_misses $perf_data_file
  calc_itlb_mpki $perf_data_file
  calc_itlb_4k_mpki $perf_data_file
  calc_itlb_2m_4m_mpki $perf_data_file
}

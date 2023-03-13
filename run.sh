#!/bin/bash
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# e: will cause the script to fail if any program it calls fails
# u: will cause the script to fail if any variable is used but it is not defined
# o pipefail will cause the script to fail if the pipe fails
set -euo pipefail

function print_usage() {
  cat <<_EOM_
Usage: run.sh [options]
  Options:
    -h|--help                   Print this help message
    --workload_1=<lang>         Run workload 1 for <lang>
    --workload_2=<lang>         Run workload 2 for <lang>
    --workload_7                Run workload 7
    --workload_8=<lang>         Run workload 8 for <lang>
    --project=<project>         Use <project> as project to use for workloads
    --bucket=<bucket>           Use <bucket> as bucket to use for workloads
    --api=<api>                 Use <api> when executing workloads
    --samples=<samples>         Number of samples to report
    --workers=<workers>         Number of workers to use when running workload
    --object_size=<object_size> Object size to use when running workload
    --region=<region>           Region used by workload7
    --upload_function=<fn>      Upload function name used by workload7
    --crc32c=<enabled>          Crc32c is enabled, disabled, random used by workload7
    --md5=<enabled>             Md5 is enabled, disabled, random used by workload7
    --minimum_read_offset=<int> Minimum read offset for range reads
    --maximum_read_offset=<int> Maximum read offset for range reads
    --write_buffer_size=<int>   Used when write buffer should contain the entire object (large object multipart uploads)
    --read_offset_quantum=<int> Quantum read offset for range reads
    --range_read_size=<int>     Range size to read from object for range reads
_EOM_
}

PARSED="$(getopt -a \
  --options="h" \
  --longoptions="help,workload_1:,workload_2:,workload_7,workload_8:,project:,bucket:,api:,samples:,object_size:,samples:,workers:,region:,upload_function:,crc32c:,md5:,minimum_read_offset:,maximum_read_offset:,read_offset_quantum:,write_buffer_size:,range_read_size:" \
  --name="run.sh" \
  -- "$@")"
eval set -- "${PARSED}"
# Get absolute path to this script to call relative files
ROOT_PATH=$(dirname $(readlink -f "${BASH_SOURCE:-$0}"))
NVM_HOME="/root/.nvm"
WORKLOAD=
PROJECT=
BUCKET_NAME=
API=
OBJECT_SIZE=
SAMPLES=
WORKERS=
REGION=
UPLOAD_FUNCTION=
CRC32C="disabled"
MD5="disabled"
WRITE_BUFFER_SIZE=
MINIMUM_READ_OFFSET=
MAXIMUM_READ_OFFSET=
READ_OFFSET_QUANTUM=
RANGE_READ_SIZE=
FORWARD_ARGS=
while true; do
  case "$1" in
    -h | --help)
      print_usage
      exit 0
      ;;
    --workload_1)
      WORKLOAD="workload_1_$2"
      shift 2
      ;;
    --workload_2)
      WORKLOAD="workload_2_$2"
      shift 2
      ;;
    --workload_7)
      WORKLOAD="workload_7"
      shift 1
      ;;
    --workload_8)
      WORKLOAD="workload_8_$2"
      shift 2
      ;;
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --bucket)
      BUCKET_NAME="$2"
      shift 2
      ;;
    --api)
      API="$2"
      shift 2
      ;;
    --object_size)
      OBJECT_SIZE="$2"
      shift 2
      ;;
    --samples)
      SAMPLES="$2"
      shift 2
      ;;
    --workers)
      WORKERS="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --upload_function)
      UPLOAD_FUNCTION="$2"
      shift 2
      ;;
    --crc32c)
      CRC32C="$2"
      shift 2
      ;;
    --md5)
      MD5="$2"
      shift 2
      ;;
    --minimum_read_offset)
      MINIMUM_READ_OFFSET="$2"
      shift 2
      ;;
    --maximum_read_offset)
      MAXIMUM_READ_OFFSET="$2"
      shift 2
      ;;
    --read_offset_quantum)
      READ_OFFSET_QUANTUM="$2"
      shift 2
      ;;
    --write_buffer_size)
      WRITE_BUFFER_SIZE="$2"
      shift 2
      ;;
    --range_read_size)
      RANGE_READ_SIZE="$2"
      shift 2
      ;;
    --)
      # condition attempts to access $2 otherwise skip
      if [ ! -z "${2-}" ]; then
        FORWARD_ARGS="$2"
      fi
      shift
      break
      ;;
  esac
done

workload_1_golang() {
  golang_benchmark_cli -p "${PROJECT}" \
                       -bucket "${BUCKET_NAME}" \
                       -workers "${WORKERS}" \
                       -min_samples "${SAMPLES}" \
                       -max_samples "${SAMPLES}" \
                       -min_size "${OBJECT_SIZE}" \
                       -max_size "${OBJECT_SIZE}" \
                       -api "${API}"
}

workload_1_nodejs() {
  . $NVM_HOME/nvm.sh
  node /usr/bin/nodejs_benchmark_cli/build/internal-tooling/performanceTest.js --project "${PROJECT}" \
                                                                                     --bucket "${BUCKET_NAME}" \
                                                                                     --test_type "w1r3" \
                                                                                     --object_size "${OBJECT_SIZE}..${OBJECT_SIZE}" \
                                                                                     --workers "${WORKERS}" \
                                                                                     --output_type "cloud-monitoring" \
                                                                                     --samples "${SAMPLES}"
}

workload_2_nodejs() {
  . $NVM_HOME/nvm.sh
  node /usr/bin/nodejs_benchmark_cli/build/internal-tooling/performanceTest.js --project "${PROJECT}" \
                                                                                     --bucket "${BUCKET_NAME}" \
                                                                                     --test_type "range-read" \
                                                                                     --object_size "${OBJECT_SIZE}..${OBJECT_SIZE}" \
                                                                                     --range_read_size "${RANGE_READ_SIZE}" \
                                                                                     --workers "${WORKERS}" \
                                                                                     --output_type "cloud-monitoring" \
                                                                                     --samples "${SAMPLES}"
}

workload_8_nodejs() {
  . $NVM_HOME/nvm.sh
  node /usr/bin/nodejs_benchmark_cli/build/internal-tooling/performanceTest.js --project "${PROJECT}" \
                                                                                     --bucket "${BUCKET_NAME}" \
                                                                                     --test_type "tm-chunked" \
                                                                                     --object_size "${OBJECT_SIZE}..${OBJECT_SIZE}" \
                                                                                     --range_read_size "${RANGE_READ_SIZE}" \
                                                                                     --workers "${WORKERS}" \
                                                                                     --output_type "cloud-monitoring" \
                                                                                     --samples "${SAMPLES}"
}

workload_7() {
  local OPTIONAL_BUFFER_SIZE_ARGS=
  if [ ! -z $WRITE_BUFFER_SIZE ]; then
    OPTIONAL_BUFFER_SIZE_ARGS="--minimum-write-buffer-size=${WRITE_BUFFER_SIZE} --maximum-write-buffer-size=${WRITE_BUFFER_SIZE}"
  fi
  local OPTIONAL_RANGE_READ_ARGS=
  if [ ! -z $MINIMUM_READ_OFFSET ] && \
     [ ! -z $MAXIMUM_READ_OFFSET ] && \
     [ ! -z $READ_OFFSET_QUANTUM ] && \
     [ ! -z $RANGE_READ_SIZE ]; then
      OPTIONAL_RANGE_READ_ARGS="--minimum-read-offset=${MINIMUM_READ_OFFSET} \
      --maximum-read-offset=${MAXIMUM_READ_OFFSET} \
      --read-offset-quantum=${READ_OFFSET_QUANTUM} \
      --minimum-read-size=${RANGE_READ_SIZE} \
      --maximum-read-size=${RANGE_READ_SIZE} \
      --read-size-quantum=${RANGE_READ_SIZE}"
  fi
  storage_throughput_vs_cpu_benchmark \
    --minimum-object-size="${OBJECT_SIZE}" \
    --maximum-object-size="${OBJECT_SIZE}" \
    --region="${REGION}" \
    --project-id="${PROJECT}" \
    --enabled-transports="${API}" \
    --minimum-sample-count="${SAMPLES}" \
    --maximum-sample-count="${SAMPLES}" \
    --upload-functions="${UPLOAD_FUNCTION}" \
    --enabled-crc32c="${CRC32C}" \
    --enabled-md5="${MD5}" \
    $OPTIONAL_BUFFER_SIZE_ARGS \
    $OPTIONAL_RANGE_READ_ARGS \
    $FORWARD_ARGS | \
    $ROOT_PATH/workload_7_output.awk
}

# Perform workload
# TODO: This can fail without non-zero result causing silent failures
COMMAND="${WORKLOAD}"
eval $COMMAND

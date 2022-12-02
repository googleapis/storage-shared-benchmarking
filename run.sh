#!/bin/bash
# e: will cause the script to fail if any program it calls fails
# u: will cause the script to fail if any variable is used but it is not defined
# o pipefail will cause the script to fail if the pipe fails
set -euo pipefail

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

function print_usage() {
  cat <<_EOM_
Usage: run.sh [options]
  Options:
    -h|--help                   Print this help message
    --workload_1=<lang>          Run workload 1 for <lang>
    --workload_7                 Run workload 7
    --project=<project>         Use <project> as project to use for workloads
    --bucket=<bucket>           Use <bucket> as bucket to use for workloads
    --api=<api>                 Use <api> when executing workloads
    --samples=<samples>         Number of samples to report
    --workers=<workers>         Number of workers to use when running workload
    --object_size=<object_size> Object size to use when running workload
    --region=<region>           Region used by workload7
    --upload_function=<fn>      Upload function name used by workload7
_EOM_
}

PARSED="$(getopt -a \
  --options="h" \
  --longoptions="help,workload_1:,workload_7,project:,bucket:,api:,samples:,object_size:,samples:,workers:,region:,upload_function:" \
  --name="run.sh" \
  -- "$@")"
eval set -- "${PARSED}"
# Get absolute path to this script to call relative files
ROOT_PATH=$(dirname $(readlink -f "${BASH_SOURCE:-$0}"))
WORKLOAD=
PROJECT=
BUCKET_NAME=
API=
OBJECT_SIZE=
SAMPLES=
WORKERS=
REGION=
UPLOAD_FUNCTION=
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
    --workload_7)
      WORKLOAD="workload_7"
      shift 1
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
    --)
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

workload_7() {
  storage_throughput_vs_cpu_benchmark \
    --minimum-object-size="${OBJECT_SIZE}" \
    --maximum-object-size="${OBJECT_SIZE}" \
    --region="${REGION}" \
    --project-id="${PROJECT}" \
    --enabled-transports="${API}" \
    --minimum-sample-count="${SAMPLES}" \
    --maximum-sample-count="${SAMPLES}" \
    --upload-functions="${UPLOAD_FUNCTION}" | \
    $ROOT_PATH/workload_7_output.awk
}

# Perform workload
COMMAND="${WORKLOAD}"
eval $COMMAND

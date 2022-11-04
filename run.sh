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
    --workload1=<lang>          Run workload 1 for <lang>
    --workload7                 Run workload 7
    --project=<project>         Use <project> as project to use for workloads
    --bucket=<bucket>           Use <bucket> as bucket to use for workloads
    --dataset=<dataset>         Use <dataset> for to write data into
    --api=<api>                 Use <api> when executing workloads
    --samples=<samples>         Number of samples to report
    --workers=<workers>         Number of workers to use when running workload
    --object_size=<object_size> Object size to use when running workload
_EOM_
}

PARSED="$(getopt -a \
  --options="h" \
  --longoptions="help,workload_1:,workload_7,project:,bucket:,dataset:,api:,samples:,object_size:,samples:,workers:" \
  --name="run.sh" \
  -- "$@")"
eval set -- "${PARSED}"
WORKLOAD=
PROJECT=
BUCKET_NAME=
BIGQUERY_DATASET=
API=
OBJECT_SIZE=
SAMPLES=
WORKERS=
while true; do
  case "$1" in
    -h | --help)
      print_usage
      exit 0
      ;;
    --workload1)
      WORKLOAD="workload_1_$2"
      shift 2
      ;;
    --workload7)
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
    --dataset)
      BIGQUERY_DATASET="$2"
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
    --)
      shift
      break
      ;;
  esac
done

workload_1_golang() {
  local SALT="$(date +'%s%N')"
  local BIGQUERY_TABLE="${WORKLOAD}"
  local RESULTS_FILE="${WORKLOAD}_results_${API}_${SALT}.csv"
  golang_benchmark_cli -p "${PROJECT}" \
                       -bucket "${BUCKET_NAME}" \
                       -defaults \
                       -workers "${WORKERS}" \
                       -min_samples "${SAMPLES}" \
                       -max_samples "${SAMPLES}" \
                       -min_size "${OBJECT_SIZE}" \
                       -max_size "${OBJECT_SIZE}" \
                       -api "${API}" \
                       -o "${RESULTS_FILE}"

  bq_cli -p "${PROJECT}" \
         -d "${BIGQUERY_DATASET}" \
         -t "${BIGQUERY_TABLE}" \
         -f "${RESULTS_FILE}"
}

workload_7() {
  local UPLOAD_OBJECT_PREFIX="test-object-$(date +'%s%N')-${API}-${OBJECT_SIZE}"
  local UPLOAD_RESULTS_FILE="${WORKLOAD}_${API}_${OBJECT_SIZE}_UPLOAD"
  local UPLOAD_RESULTS_FILE_PROCESSED="${UPLOAD_RESULTS_FILE}_PROCESSED"
  /usr/bin/aggregate_upload_throughput_benchmark \
    --labels=workload_7_upload \
    --api="${API}" \
    --object-count=1 \
    --minimum-object-size="${OBJECT_SIZE}" \
    --maximum-object-size="${OBJECT_SIZE}" \
    --bucket-name="${BUCKET_NAME}" \
    --object-prefix="${UPLOAD_OBJECT_PREFIX}" \
    --iteration-count="${SAMPLES}" > "${UPLOAD_RESULTS_FILE}"
  cat "${UPLOAD_RESULTS_FILE}" | \
      grep -v "#.*" > "${UPLOAD_RESULTS_FILE_PROCESSED}"
  tail -n +2 "${UPLOAD_RESULTS_FILE_PROCESSED}" | awk -F, '{print "throughput{workload="$2",Iteration="$1",ObjectCount="$3",ResumableUploadChunkSize="$4",ThreadCount="$5",Api="$6",GrpcChannelCount="$7",GrpcPluginConfig="$8",RestHttpVersion="$9",ClientPerThread="$10",StatusCode="$11",Peer="$12",BytesUploaded="$13",ElapsedMicroseconds="$14",IterationBytes="$15",IterationElapsedMicroseconds="$16",IterationCpuMicroseconds="$17"} "(($13/1024/1024)/($14/1000000))}'
  rm "${UPLOAD_RESULTS_FILE_PROCESSED}" "${UPLOAD_RESULTS_FILE}"

  local DOWNLOAD_OBJECT_PREFIX="test-object-$(date +'%s%N')-${API}-${OBJECT_SIZE}"
  local DOWNLOAD_RESULTS_FILE="${WORKLOAD}_${API}_${OBJECT_SIZE}_DOWNLOAD"
  local DOWNLOAD_RESULTS_FILE_PROCESSED="${DOWNLOAD_RESULTS_FILE}_PROCESSED"
  /usr/bin/create_dataset \
    --bucket-name="${BUCKET_NAME}" \
    --object-prefix="${DOWNLOAD_OBJECT_PREFIX}" \
    --minimum-object-size="${OBJECT_SIZE}" \
    --maximum-object-size="${OBJECT_SIZE}" \
    --object-count=1 \
    --thread-count=1 > /dev/null
  /usr/bin/aggregate_download_throughput_benchmark \
    --labels=workload_7_download \
    --api="${API}" \
    --bucket-name="${BUCKET_NAME}" \
    --object-prefix="${DOWNLOAD_OBJECT_PREFIX}" \
    --iteration-count="${SAMPLES}" > "${DOWNLOAD_RESULTS_FILE}"
  cat "${DOWNLOAD_RESULTS_FILE}" | \
      grep -v "#.*" > "${DOWNLOAD_RESULTS_FILE_PROCESSED}"
  tail -n +2 "${DOWNLOAD_RESULTS_FILE_PROCESSED}" | awk -F, '{print "throughput{workload="$1",Iteration="$2",ObjectCount="$3",DatasetSize="$4",ThreadCount="$5",RepeatsPerIteration="$6",ReadSize="$7",ReadBufferSize="$8",Api="$9",GrpcChannelCount="$10",GrpcPluginConfig="$11",ClientPerThread="$12",StatusCode="$13",Peer="$14",BytesDownloaded="$15",ElapsedMicroseconds="$16",IterationBytes="$17",IterationElapsedMicroseconds="$18",IterationCpuMicroseconds="$19"} "(($4/1024/1024)/($16/1000000))}'
  rm "${DOWNLOAD_RESULTS_FILE_PROCESSED}" "${DOWNLOAD_RESULTS_FILE}"
}

# Perform workload
COMMAND="${WORKLOAD}"
eval $COMMAND

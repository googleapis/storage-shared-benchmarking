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

# Parameters
WORKLOAD=$1
PROJECT=$2
BUCKET_NAME=$3
BIGQUERY_DATASET=$4
API="${5}"
OBJECT_SIZE="${6}"
WORKERS="${7}"

workload_1_golang() {
  SALT="$(date +'%s%N')"
  BIGQUERY_TABLE="${WORKLOAD}"
  RESULTS_FILE="${WORKLOAD}_results_${API}_${SALT}.csv"
  golang_benchmark_cli -p "${PROJECT}" \
                       -bucket "${BUCKET_NAME}" \
                       -defaults \
                       -workers "${WORKERS}" \
                       -min_samples 100 \
                       -max_samples 100 \
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
  OBJECT_PREFIX="test-object-$(date +'%s%N')"
  # Run benchmarks
  /usr/bin/create_dataset \
    --bucket-name="${BUCKET_NAME}" \
    --object-prefix="${OBJECT_PREFIX}-${API}-${OBJECT_SIZE}" \
    --minimum-object-size="${OBJECT_SIZE}" \
    --maximum-object-size="${OBJECT_SIZE}" \
    --object-count=1 \
    --thread-count=1
  UPLOAD_BIGQUERY_TABLE="${WORKLOAD}_${API}_upload"
  UPLOAD_RESULTS_FILE="${WORKLOAD}_${API}_${OBJECT_SIZE}_upload"
  UPLOAD_RESULTS_FILE_PROCESSED="${UPLOAD_RESULTS_FILE}_PROCESSED"
  /usr/bin/aggregate_upload_throughput_benchmark \
    --labels=workload_7 \
    --api="${API}" \
    --object-count=1 \
    --client-per-thread=1 \
    --minimum-object-size="${OBJECT_SIZE}" \
    --maximum-object-size="${OBJECT_SIZE}" \
    --bucket-name="${BUCKET_NAME}" \
    --object-prefix="${OBJECT_PREFIX}-${API}-${OBJECT_SIZE}" \
    --iteration-count=1 > "${UPLOAD_RESULTS_FILE}"
  cat "${UPLOAD_RESULTS_FILE}" | \
      grep -v "#.*" > "${UPLOAD_RESULTS_FILE_PROCESSED}"
  bq_cli -p "${PROJECT}" -d "${BIGQUERY_DATASET}" -t "${UPLOAD_BIGQUERY_TABLE}" -f "${UPLOAD_RESULTS_FILE_PROCESSED}"
  DOWNLOAD_BIGQUERY_TABLE="${WORKLOAD}_${API}_download"
  DOWNLOAD_RESULTS_FILE="${WORKLOAD}_${API}_${OBJECT_SIZE}_download"
  DOWNLOAD_RESULTS_FILE_PROCESSED="${DOWNLOAD_RESULTS_FILE}_PROCESSED"
  /usr/bin/aggregate_download_throughput_benchmark \
    --labels=workload_7 \
    --api="${API}" \
    --client-per-thread=1 \
    --read-size="${OBJECT_SIZE}" \
    --read-buffer-size="${OBJECT_SIZE}" \
    --bucket-name="${BUCKET_NAME}" \
    --object-prefix="${OBJECT_PREFIX}-${API}-${OBJECT_SIZE}" \
    --iteration-count=1 > "${DOWNLOAD_RESULTS_FILE}"
  cat "${DOWNLOAD_RESULTS_FILE}" | \
      grep -v "#.*" > "${DOWNLOAD_RESULTS_FILE_PROCESSED}"
  bq_cli -p "${PROJECT}" -d "${BIGQUERY_DATASET}" -t "${DOWNLOAD_BIGQUERY_TABLE}" -f "${DOWNLOAD_RESULTS_FILE_PROCESSED}"
}

# Perform workload
COMMAND="${WORKLOAD}"
eval $COMMAND

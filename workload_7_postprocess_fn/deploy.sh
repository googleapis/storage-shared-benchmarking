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

gcloud services -q enable cloudscheduler.googleapis.com cloudfunctions.googleapis.com
REGION="us-central1"
FUNCTION_NAME="workload-7-postprocess"
gcloud functions -q deploy "${FUNCTION_NAME}"  \
       --gen2 \
       --runtime python310 \
       --trigger-http \
       --entry-point "run_workload_7_post_processing" \
       --region "${REGION}" \
       --memory 4GB \
       --source=. \
       --timeout 600

URI=$(gcloud functions describe "${FUNCTION_NAME}" | \
       grep "uri: " |
       awk -F': ' '{print $2}')

DEFAULT_SERVICE_ACCOUNT=$(gcloud functions describe "${FUNCTION_NAME}" | \
       grep "serviceAccountEmail: " |
       awk -F': ' '{print $2}')

SCHEDULER_NAME=workload_7_postprocess_trigger_test

gcloud scheduler jobs delete -q --location "${REGION}" "${SCHEDULER_NAME}" || true
gcloud scheduler jobs create -q http "${SCHEDULER_NAME}" \
  --location "${REGION}" \
  --schedule "0 0 * * 0-7" \
  --http-method "post" \
  --uri "${URI}" \
  --oidc-service-account-email "${DEFAULT_SERVICE_ACCOUNT}" \
  --time-zone "America/Los_Angeles"

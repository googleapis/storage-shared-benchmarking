#!/bin/bash
# Copyright 2023 Google LLC
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

function exec_awk_pipeline() {
  cat $1 | ../../workload_7_output.awk > $2
}

function test_examples() {
  pushd examples
  for f in `ls workload_7_example_*`; do
    EXPECT_RESULT="expected_result_${f}"
    ACTUAL_RESULT="/tmp/${f}_result"
    exec_awk_pipeline $f $ACTUAL_RESULT
    diff $EXPECT_RESULT $ACTUAL_RESULT
  done
  popd
}

test_examples

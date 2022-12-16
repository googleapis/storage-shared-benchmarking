#!/usr/bin/awk -f
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

BEGIN {
  FS=",";
  MIB=1048576;
  KIB=1024
  US_TO_S=1000000;
}
{
  # Only select lines that start with 202
  if (match($0, /^202/)) {
    TRANSFER_SIZE=$8
    ELAPSED_TIME_US=$12
    THROUGHPUT=(TRANSFER_SIZE/MIB)/(ELAPSED_TIME_US/US_TO_S);
    # Switch to kibps for objects smaller than a MIB
    if (TRANSFER_SIZE < MIB) {
      THROUGHPUT=(TRANSFER_SIZE/KIB)/(ELAPSED_TIME_US/US_TO_S);
    }
    printf("throughput{library="$3);
    printf(",api="$4",op="$5",object_size="$6",transfer_offset="$7);
    printf(",transfer_size="TRANSFER_SIZE",app_buffer_size="$9",crc32c_enabled="$10);
    printf(",md5_enabled="$11",elapsed_time_us="ELAPSED_TIME_US",cpu_time_us="$13);
    printf(",peer="$14",bucket_name="$15",object_name="$16);
    printf(",generation="$17",upload_id="$18",retry_count="$19);
    print(",status_code="$20"}",THROUGHPUT);
  }
}

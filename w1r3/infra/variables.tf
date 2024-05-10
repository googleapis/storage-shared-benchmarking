# Copyright 2024 Google LLC
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

variable "project" {
  default = "storage-sdk-prober-project"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-f"
}

variable "replicas" {
  # TODO(#80) - run one instance per region. Setting this to 4 did not work as
  #     I (coryan@) expected.
  default = 3
}

# use `-var=app_version_go=v2` to redeploy when the changes do not trigger
# a terraform change. See mig/go/main.tf for details.
variable "app_version_go" {
  default = "v1"
}

# use `-var=app_version_java=v2` to redeploy when the changes do not trigger
# a terraform change. See mig/go/main.tf for details.
variable "app_version_java" {
  default = "v1"
}

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

variable "metric-prefix" {
    default = "ssb/w1r3"
}

resource "google_monitoring_metric_descriptor" "latency" {
  description = "Operation latency as measured by the benchmark."
  display_name = "Operation Latency"
  type = "workload.googleapis.com/${var.metric-prefix}/latency"
  metric_kind = "CUMULATIVE"
  value_type = "DISTRIBUTION"
  unit = "s"

  labels {
    key = "service_namespace"
    value_type = "STRING"
  }
  labels {
    key = "service_name"
    value_type = "STRING"
  }
  labels {
    key = "service_instance_id"
    value_type = "STRING"
  }

  labels {
    key = "ssb_language"
    value_type = "STRING"
  }
  labels {
    key = "ssb_deployment"
    value_type = "STRING"
  }
  labels {
    key = "ssb_instance"
    value_type = "STRING"
  }
  labels {
    key = "ssb_transport"
    value_type = "STRING"
  }
  labels {
    key = "ssb_object_size"
    value_type = "STRING"
  }
  labels {
    key = "ssb_op"
    value_type = "STRING"
  }

  labels {
    key = "ssb_version"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_sdk"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_http"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_grpc"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_protobuf"
    value_type = "STRING"
  }
}

resource "google_monitoring_metric_descriptor" "cpu" {
  description = "CPU usage as measured by the benchmark."
  display_name = "CPU Usage"
  type = "workload.googleapis.com/${var.metric-prefix}/cpu"
  metric_kind = "CUMULATIVE"
  value_type = "DISTRIBUTION"
  unit = "s"

  labels {
    key = "service_namespace"
    value_type = "STRING"
  }
  labels {
    key = "service_name"
    value_type = "STRING"
  }
  labels {
    key = "service_instance_id"
    value_type = "STRING"
  }

  labels {
    key = "ssb_language"
    value_type = "STRING"
  }
  labels {
    key = "ssb_deployment"
    value_type = "STRING"
  }
  labels {
    key = "ssb_instance"
    value_type = "STRING"
  }
  labels {
    key = "ssb_transport"
    value_type = "STRING"
  }
  labels {
    key = "ssb_object_size"
    value_type = "STRING"
  }
  labels {
    key = "ssb_op"
    value_type = "STRING"
  }

  labels {
    key = "ssb_version"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_sdk"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_http"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_grpc"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_protobuf"
    value_type = "STRING"
  }
}

resource "google_monitoring_metric_descriptor" "memory" {
  description = "Memory usage usage as measured by the benchmark."
  display_name = "Memory Usage"
  type = "workload.googleapis.com/${var.metric-prefix}/memory"
  metric_kind = "CUMULATIVE"
  value_type = "DISTRIBUTION"
  unit = "By"


  labels {
    key = "service_namespace"
    value_type = "STRING"
  }
  labels {
    key = "service_name"
    value_type = "STRING"
  }
  labels {
    key = "service_instance_id"
    value_type = "STRING"
  }

  labels {
    key = "ssb_language"
    value_type = "STRING"
  }
  labels {
    key = "ssb_deployment"
    value_type = "STRING"
  }
  labels {
    key = "ssb_instance"
    value_type = "STRING"
  }
  labels {
    key = "ssb_transport"
    value_type = "STRING"
  }
  labels {
    key = "ssb_object_size"
    value_type = "STRING"
  }
  labels {
    key = "ssb_op"
    value_type = "STRING"
  }

  labels {
    key = "ssb_version"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_sdk"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_http"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_grpc"
    value_type = "STRING"
  }
  labels {
    key = "ssb_version_protobuf"
    value_type = "STRING"
  }
}

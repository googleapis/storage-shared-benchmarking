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

locals {
  metrics = {
    latency = {
      description  = "Operation latency as measured by the benchmark."
      display_name = "Operation Latency"
      unit         = "s"
    }
    cpu = {
      description  = "CPU usage per byte as measured by the benchmark."
      display_name = "CPU Usage"
      unit         = "ns/By{CPU}"
    }
    memory = {
      description  = "Memory usage per byte as measured by the benchmark."
      display_name = "Memory Usage"
      unit         = "1{memory}"
    }
  }
}

resource "google_monitoring_metric_descriptor" "default" {
  for_each     = tomap(local.metrics)
  description  = each.value.description
  display_name = each.value.display_name
  unit         = each.value.unit
  type         = "workload.googleapis.com/${var.metric-prefix}/${each.key}"
  metric_kind  = "CUMULATIVE"
  value_type   = "DISTRIBUTION"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels, description, display_name, unit]
  }

  # We do not set the description field because any changes will cause terraform
  # to drop and recreate the metric, losing all the data.
  labels {
    key        = "service_namespace"
    value_type = "STRING"
    # Maps to `namespace` in a `generic_task` monitored resource type. A
    # namespace identifier, such as a cluster name."
  }
  labels {
    key        = "service_name"
    value_type = "STRING"
    # Maps to `job` in a `generic_task` monitored resource type. An identifier
    # for a grouping of related tasks, such as the name of a microservice or
    # distributed batch job.
  }
  labels {
    key        = "service_instance_id"
    value_type = "STRING"
    # Maps to `task_id` in a `generic_task` monitored resource type. A unique
    # identifier for the task within the namespace and job, such as a replica
    # index identifying the task within the job.
  }

  labels {
    key        = "ssb_language"
    value_type = "STRING"
    # The benchmark and SDK programming language.
  }
  labels {
    key        = "ssb_deployment"
    value_type = "STRING"
    # Where is the SDK deployed. Typically this indicates the
    # deployment environment, as in `gke` or `mig` (Managed Instance Group).
    # It may represent a custom deployment, e.g. `development` or 
    # `mig-with-fancy-network`.
  }
  labels {
    key        = "ssb_instance"
    value_type = "STRING"
    # A unique identifier for the process running the benchmark. We use UUIDv4
    # to generate these identifiers.
  }
  labels {
    key        = "ssb_node_id"
    value_type = "STRING"
    # The GCE instance id.
  }
  labels {
    key        = "ssb_transport"
    value_type = "STRING"
    # The transport, that is, whether the results were captured using the JSON
    # API, or gRPC+CFE, or gRPC+DP.
  }
  labels {
    key        = "ssb_object_size"
    value_type = "STRING"
    # The size of the object used to capture these results.
  }
  labels {
    key        = "ssb_op"
    value_type = "STRING"
    # The operation represented by these results. Typically one of:
    # - RESUMABLE: an upload using the resumable uploads APIs.
    # - SINGLE-SHOT: an upload using the single shot APIs.
    # - READ[0]: the first read of the object.
    # - READ[1]: the second read of the object.
    # - READ[2]: the third read of the object, finish the W1R3 "workload".
  }

  labels {
    key        = "ssb_version"
    value_type = "STRING"
    # The version of the benchmark, e.g. as captured by `git rev-parse HEAD`.
  }
  labels {
    key        = "ssb_version_sdk"
    value_type = "STRING"
    # The version of the storage SDK.
  }
  labels {
    key        = "ssb_version_http_client"
    value_type = "STRING"
    # The version of the HTTP client used by the SDK.
  }
  labels {
    key        = "ssb_version_http"
    value_type = "STRING"
    # The version of HTTP used by the SDK.
  }
  labels {
    key        = "ssb_version_grpc"
    value_type = "STRING"
    # The version of gRPC used by the SDK.
  }
  labels {
    key        = "ssb_version_protobuf"
    value_type = "STRING"
    # The version of Protobuf used by the SDK.
  }
}

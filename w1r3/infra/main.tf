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

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.29.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

# Create a bucket to store the data used in the benchmark. This data is expected
# to be ephemeral. Any data older than 15 days gets automatically removed.
# Only very long running benchmarks may need data for longer than this, and they
# can refresh the data periodically to avoid running afoul of the lifecycle
# rule.
resource "google_storage_bucket" "w1r3" {
  name                        = "gcs-grpc-team-${var.project}-w1r3-${var.region}"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 15
    }
    action {
      type = "Delete"
    }
  }
}

# Create the metric descriptors used by the benchmark.
# TODO(#77) - remove the metric management until we figure out how to do better.
# module "metrics" {
#   source = "./metrics"
# }

module "mig-sa" {
  source  = "./mig/service-account"
  project = var.project
  bucket  = google_storage_bucket.w1r3.name
}

module "histograms" {
  source = "./dashboards"
}

module "mig-cpp" {
  source          = "./mig/cpp"
  project         = var.project
  bucket          = google_storage_bucket.w1r3.name
  region          = var.region
  replicas        = var.replicas
  service_account = module.mig-sa.email
  app_version     = var.app_version_cpp
  depends_on      = [module.mig-sa]
}

module "mig-go" {
  source          = "./mig/go"
  project         = var.project
  bucket          = google_storage_bucket.w1r3.name
  region          = var.region
  replicas        = var.replicas
  service_account = module.mig-sa.email
  app_version     = var.app_version_go
  depends_on      = [module.mig-sa]
}

module "mig-java" {
  source          = "./mig/java"
  project         = var.project
  bucket          = google_storage_bucket.w1r3.name
  region          = var.region
  replicas        = var.replicas
  service_account = module.mig-sa.email
  app_version     = var.app_version_java
  depends_on      = [module.mig-sa]
}

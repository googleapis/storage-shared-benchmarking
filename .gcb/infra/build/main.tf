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

variable "project" {}
variable "region" {}

locals {
  # Google Cloud Build installs an application on the GitHub organization or
  # repository. This id is hard-coded here because there is no easy way [^1] to
  # manage that installation via terraform.
  #
  # [^1]: there is a way, described in [Connecting a Gitub host programmatically]
  #     but I would not call that "easy". It requires (for example) manually
  #     creating a personally access token (PAT) on GitHub, and storing that
  #     in the Terraform file.
  # [Connecting a Gitub host programmatically]: https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github?generation=2nd-gen#terraform
  #
  gcb_app_installation_id = 1168573

  # Google Cloud build stores a secret to access Github in secret manager. The
  # UI creates a secret name that we record here.
  gcb_secret_name = "projects/${var.project}/secrets/github-github-oauthtoken-790dbd/versions/latest"
}

# This is used to retrieve the project number. The project number is embedded in
# certain P4 (Per-product per-project) service accounts.
data "google_project" "project" {
}

resource "google_cloudbuildv2_connection" "github" {
  project  = var.project
  location = var.region
  name     = "github"

  github_config {
    app_installation_id = local.gcb_app_installation_id
    authorizer_credential {
      oauth_token_secret_version = local.gcb_secret_name
    }
  }
}

resource "google_cloudbuildv2_repository" "cpp-storage-prelaunch" {
  project           = var.project
  location          = var.region
  name              = "googleapis-cpp-storage-prelaunch"
  parent_connection = google_cloudbuildv2_connection.github.name
  remote_uri        = "https://github.com/googleapis/storage-shared-benchmarking.git"
}

output "repository" {
  value = google_cloudbuildv2_repository.cpp-storage-prelaunch.id
}

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
  type = string
}

variable "bucket" {
  type = string
}

variable "region" {
  type = string
}

variable "replicas" {
  type = number
}

variable "service_account" {
  type = string
}

variable "app_version" {
  type    = string
  default = "v1"
}

locals {
  # Including the version in the name simplifies updates. An `apply` will
  # delete the previous version and create a new one.
  runner-template    = "go-runner-template-${var.app_version}"
  runner-group       = "go-runner-${var.app_version}"
  base_instance_name = "w1r3-go"
  cpus               = 4
  iterations         = 1000000
}

resource "google_compute_instance_template" "default" {
  name = local.runner-template
  disk {
    auto_delete  = true
    boot         = true
    device_name  = "persistent-disk-0"
    mode         = "READ_WRITE"
    source_image = "projects/cos-cloud/global/images/family/cos-stable"
    type         = "PERSISTENT"
  }
  labels = {
    w1r3-lang = "go"
  }
  machine_type = "c2d-standard-${local.cpus}"
  metadata = {
    cos-metrics-enabled = true
    user-data           = <<EOF
 #cloud-config

users:
- name: cloudservice
  uid: 2000
  
write_files:
- path: /etc/systemd/system/w1r3@.service
  permissions: 0644
  owner: root
  content: |
    [Unit]
    Description=The golang w1r3 continuous benchmark instance %I
    StartLimitIntervalSec=300
    StartLimitBurst=3

    [Service]
    Restart=always
    RestartSec=1s

    Environment="HOME=/home/cloudservice"
    ExecStartPre=/usr/bin/docker-credential-gcr configure-docker ; /usr/bin/docker pull gcr.io/${var.project}/w1r3/go:latest
    ExecStart=/usr/bin/docker run --rm -u 2000 --name=w1r3-go-%i gcr.io/${var.project}/w1r3/go:latest /r/w1r3 -project-id ${var.project} -bucket ${var.bucket} -iterations ${local.iterations} -deployment mig
    ExecStop=/usr/bin/docker stop w1r3-go
    ExecStopPost=/usr/bin/docker rm w1r3-go

runcmd:
- docker-credential-gcr configure-docker
- systemctl daemon-reload
- for i in $(seq 0 ${local.cpus}); do systemctl start w1r3@$${i}.service; done
EOF
  }
  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }
    nic_type   = "GVNIC"
    network    = "default"
    subnetwork = "default"
  }
  region = var.region
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    provisioning_model  = "STANDARD"
  }
  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "default" {
  name   = local.runner-group
  region = var.region
  version {
    instance_template = google_compute_instance_template.default.id
    name              = "primary"
  }
  base_instance_name = local.base_instance_name
  target_size        = var.replicas

  # NOTE: the name of this resource must be unique for every update;
  #       this is wy we have a app_version in the name; this way
  #       new resource has a different name vs old one and both can
  #       exists at the same time
  lifecycle {
    create_before_destroy = true
  }
}

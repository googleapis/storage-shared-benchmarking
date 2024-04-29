# Google Cloud Build support

This directory contains configuration files and scripts to support GCB (Google
Cloud Build) builds.

We generally prefer GHA (GitHub Actions) for CI (Continuous Integration):
building the code, running unit test, run any linters or formatters.

We use GCB for CD (Continuous Deployment): creating docker images in
Google Cloud, and deploying these images to Google Cloud.

GCB can perform these operations with relatively simple management for
authentication and authorization. The GCB builds run using a service account
specific to our project. We can grant this service account the necessary
permissions to act on the benchmark infrastructure, and nothing else. And we can
manage these permissions using Terraform, just like we are managing the rest of
the infrastructure.

In contrast, if we wanted to use GHA for the same role, we would need to either
(1) download a service account key file and install it as a GHA secret, and
manually rotate this secret, or (2) configure workload identify federation
between GitHub and our project. Neither approach is very easy to reason about
from a security perspective.

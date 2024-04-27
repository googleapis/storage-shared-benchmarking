# Google Cloud Build support

This directory contains configuration files and scripts to support GCB (Google
Cloud Build) builds.

We generally prefer GHA (GitHub Actions) for CI (Continuous Integration):
building the code, running unit test, run any linters or formatters.

We use GCB is better for CD (Continuous Deployment): creating docker images in
Google Cloud, and deploying these images to Google Cloud. GCB can perform these
operations without relatively simple management for authorization and
permissions. The GCB builds run using a service account specific to our project.
We can grant these service account the necessary permissions to act on the
benchmark infrastructure, and nothing else.

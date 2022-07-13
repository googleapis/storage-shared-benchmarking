#!/bin/bash
# Make sure Application Default Credentials is using the benchmarking service
# account by using its key file, which is stashed in the trusted tester bucket.
# This only applies to GCE instances in bigstore-gsutil-testing!
gcloud alpha storage cp gs://do-not-delete-tt/key.json .
export GOOGLE_APPLICATION_CREDENTIALS="key.json"
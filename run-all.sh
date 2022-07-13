#!/bin/bash

$(dirname "$0")/run.sh aws $1
$(dirname "$0")/run.sh curl $1
$(dirname "$0")/run.sh gcsfast $1
$(dirname "$0")/run.sh gs $1
$(dirname "$0")/run.sh gsnohash $1
$(dirname "$0")/run.sh gsutil $1
$(dirname "$0")/run.sh gsutilnohash $1

gsutil -m cp time-* gs://do-not-delete-us-east4/time-$1
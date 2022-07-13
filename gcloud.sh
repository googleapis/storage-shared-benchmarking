#!/bin/bash
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-332.0.0-linux-x86_64.tar.gz
tar xvfz google-cloud-sdk-332.0.0-linux-x86_64.tar.gz
google-cloud-sdk/install.sh
google-cloud-sdk/bin/gcloud components repositories add https://storage.googleapis.com/do-not-delete-tt/components-2.json
google-cloud-sdk/bin/gcloud components update
google-cloud-sdk/bin/gcloud alpha storage cp gs://do-not-delete-tt/key.json .
# some gsutil stuff as well
pip install --no-cache-dir -U crcmod
cp $(dirname "$0")/.boto ~/
echo "Cool. Now run 'source .bashrc' so you use the new installation."

#!/bin/bash

# Clear out anything left over from previous runs.
rm trials-gcloud.csv

# Returns a timestamp with 3 digits of nanoseconds.
timestamp() {
  date +'%s%N' | cut -b1-13
}

echo "workload,process_count,thread_count,max_slices,time" >> trials-gcloud.csv

for p in 2 4 6 8 16 
do
  for t in 1 2 4 6 10
  do
    echo "1000x1M,$p,$t"
    sync && echo 3 > sudo /proc/sys/vm/drop_caches
    start=$(timestamp)
    CLOUDSDK_STORAGE_CHECK_HASHES=never CLOUDSDK_STORAGE_PROCESS_COUNT=$p CLOUDSDK_STORAGE_THREAD_COUNT=$t CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M gcloud alpha storage cp -r /mnt/disks/scratch/gs-1000x1M gs://do-not-delete-opt-$1/  
    end=$(timestamp)
    time=$(bc <<< "scale=3 ; ($end - $start) / 1000")
    echo "1000x1M,$p,$t,0,$time" >> trials-gcloud.csv
    echo "1x1G,$p,$t,$slices"
    sync && echo 3 > sudo /proc/sys/vm/drop_caches
    start=$(timestamp)
    CLOUDSDK_STORAGE_CHECK_HASHES=never CLOUDSDK_STORAGE_PROCESS_COUNT=$p CLOUDSDK_STORAGE_THREAD_COUNT=$t CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M gcloud alpha storage cp -r /mnt/disks/scratch/gs-1x1G gs://do-not-delete-opt-$1/
    end=$(timestamp)
    time=$(bc <<< "scale=3 ; ($end - $start) / 1000")
    echo "1x1G,$p,$t,$slices,$time" >> trials-gcloud.csv
  done
done

gsutil -m cp trials-* gs://do-not-delete-us-east4/trial-$1/
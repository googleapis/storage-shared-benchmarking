#!/bin/bash

# Clear out anything left over from previous runs.
rm trials-gsutil.csv
rm trials-gcloud.csv
rm -rf /mnt/disks/scratch/trial-gsutil
rm -rf /mnt/disks/scratch/trial-gcloud
mkdir /mnt/disks/scratch/trial-gsutil
mkdir /mnt/disks/scratch/trial-gcloud

# Returns a timestamp with 3 digits of nanoseconds.
timestamp() {
  date +'%s%N' | cut -b1-13
}

echo "workload,process_count,thread_count,max_slices,time" >> trials-gsutil.csv

for p in 2 4 6 8 16
do
  for t in 1 2 4 6 10
  do
    echo "1000x1M,$p,$t"
    echo 3 > sudo /proc/sys/vm/drop_caches
    start=$(timestamp)
    gsutil -m -o'GSUtil:check_hashes=never' -o"GSUtil:parallel_process_count=$p" -o"GSUtil:parallel_thread_count=$t" cp -r gs://do-not-delete-us-east4/1000x1M/* /mnt/disks/scratch/trial-gsutil
    end=$(timestamp)
    time=$(bc <<< "scale=3 ; ($end - $start) / 1000")
    echo "1000x1M,$p,$t,0,$time" >> trials-gsutil.csv
    rm /mnt/disks/scratch/trial-gsutil/*
    for s in 1 10 20 100
    do
      [[ $s = 1 ]] && slices=$(( p * t )) || slices=$s
      echo "1x1G,$p,$t,$slices"
      echo 3 > sudo /proc/sys/vm/drop_caches
      start=$(timestamp)
      gsutil -m -o'GSUtil:check_hashes=never' -o"GSUtil:parallel_process_count=$p" -o"GSUtil:parallel_thread_count=$t" -o"GSUtil:sliced_object_download_max_components=$slices" cp -r gs://do-not-delete-us-east4/1x1G/* /mnt/disks/scratch/trial-gsutil
      end=$(timestamp)
      time=$(bc <<< "scale=3 ; ($end - $start) / 1000")
      echo "1x1G,$p,$t,$slices,$time" >> trials-gsutil.csv
      rm /mnt/disks/scratch/trial-gsutil/*
    done
  done
done

echo "workload,process_count,thread_count,max_slices,time" >> trials-gcloud.csv

for p in 2 4 6 8 16 
do
  for t in 1 2 4 6 10
  do
    echo "1000x1M,$p,$t"
    echo 3 > sudo /proc/sys/vm/drop_caches
    start=$(timestamp)
    CLOUDSDK_STORAGE_CHECK_HASHES=never CLOUDSDK_STORAGE_PROCESS_COUNT=$p CLOUDSDK_STORAGE_THREAD_COUNT=$t gcloud alpha storage cp -r gs://do-not-delete-us-east4/1000x1M/* /mnt/disks/scratch/trial-gcloud
    end=$(timestamp)
    time=$(bc <<< "scale=3 ; ($end - $start) / 1000")
    echo "1000x1M,$p,$t,0,$time" >> trials-gcloud.csv
    rm /mnt/disks/scratch/trial-gcloud/*
    for s in 1 10 20
    do
      [[ $s = 1 ]] && slices=$(( p * t )) || slices=$s
      echo "1x1G,$p,$t,$slices"
      echo 3 > sudo /proc/sys/vm/drop_caches
      start=$(timestamp)
      CLOUDSDK_STORAGE_SLICED_OBJECT_DOWNLOAD_COMPONENT_SIZE=1Mi CLOUDSDK_STORAGE_CHECK_HASHES=never CLOUDSDK_STORAGE_PROCESS_COUNT=$p CLOUDSDK_STORAGE_THREAD_COUNT=$t CLOUDSDK_STORAGE_SLICED_OBJECT_DOWNLOAD_MAX_COMPONENTS=$slices gcloud alpha storage cp -r gs://do-not-delete-us-east4/1x1G/* /mnt/disks/scratch/trial-gcloud
      end=$(timestamp)
      time=$(bc <<< "scale=3 ; ($end - $start) / 1000")
      echo "1x1G,$p,$t,$slices,$time" >> trials-gcloud.csv
      rm /mnt/disks/scratch/trial-gcloud/*
    done
  done
done

gsutil -m cp trials-* gs://do-not-delete-us-east4/trial-$1/
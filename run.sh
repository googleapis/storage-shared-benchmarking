#!/bin/bash
app=$1
cores=$2
folders=( /tmp /mnt/disks/scratch /dev/shm )
work=( 1x10G 1x5G 1x1G 1x100M 1x10M 1x1M 1x1K 100x100M 100x10M 100x1M 100x1K 1000x10M 1000x1M 1000x1K )

# Some workloads are too big to put in RAM on some machines.
too_big=""
# Some workloads just aren't supported in general.
skip=""

# Download/upload commands.
dl=""
ul=""

# Set the workloads that should be skipped on RAM on small machines.
if [[ $cores -lt 16 ]]; then
  too_big="1x10G 1x5G 100x100M 1000x10M"
fi

# Set the commands for the various apps.
case "$app" in
  cpp)
    dl="~/google-cloud-cpp/cmake-out/home/google/cloud/storage/benchmarks/storage_throughput_vs_cpu_benchmark --project-id=spec-test-ruby-samples --region=us-central1 --enabled-apis=xml --thread-count=1 --minimum-object-size=16MiB --maximum-object-size=256MiB --minimum-sample-count=1 --duration=5s"
    ul="~/google-cloud-cpp/cmake-out/home/google/cloud/storage/benchmarks/storage_throughput_vs_cpu_benchmark --project-id=spec-test-ruby-samples --region=us-central1 --enabled-apis=xml --thread-count=1 --minimum-object-size=16MiB --maximum-object-size=256MiB --minimum-sample-count=1 --duration=5s"
    ;;

  aws)
    skip="1x10G"
    dl="aws s3 cp --recursive s3://do-not-delete-benchmark-gs/WORK FOLDER/aws-WORK"
    ul="aws s3 cp --recursive FOLDER/aws-WORK s3://do-not-delete-benchmark-gs/"
    ;;

  curl)
    skip="100x100M 100x10M 100x1M 100x1K 1000x10M 1000x1M 1000x1K"
    dl="curl https://storage.googleapis.com/do-not-delete-us-east4/WORK/file1.txt -o FOLDER/curl-WORK.txt"
    ;;

  gcsfast)
    dl="cd FOLDER/gcsfast-WORK && gsutil ls gs://do-not-delete-us-east4/WORK | xargs -I{} gcsfast download {} . && cd -"
    ul="cd FOLDER/gcsfast-WORK && find . -type f -exec gcsfast upload {} gs://do-not-delete-us-east4/file1.txt \; && cd -"
    ;;

  gs)
    dl="benchmarking/timeout.sh -t 500 gcloud alpha storage cp -r gs://do-not-delete-us-east4/WORK/* FOLDER/gs-WORK/"
    ul="CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M benchmarking/timeout.sh -t 500 gcloud alpha storage cp -r FOLDER/gs-WORK/* gs://do-not-delete-us-east4/"
    ;;

  gsnohash)
    dl="CLOUDSDK_STORAGE_CHECK_HASHES=never benchmarking/timeout.sh -t 500 gcloud alpha storage cp -r gs://do-not-delete-us-east4/WORK/* FOLDER/gsnohash-WORK/"
    ul="CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M CLOUDSDK_STORAGE_CHECK_HASHES=never benchmarking/timeout.sh -t 500 gcloud alpha storage cp -r FOLDER/gsnohash-WORK/* gs://do-not-delete-us-east4/"
    ;;

  gsutil)
    dl="gsutil -m cp -r gs://do-not-delete-us-east4/WORK/* FOLDER/gsutil-WORK/"
    ul="gsutil -m cp -r FOLDER/gsutil-WORK/* gs://do-not-delete-us-east4/"
    ;;

  gsutilnohash)
    dl="gsutil -m -o'GSUtil:check_hashes=never' cp -r gs://do-not-delete-us-east4/WORK/* FOLDER/gsutilnohash-WORK/"
    ul="gsutil -m -o'GSUtil:check_hashes=never' cp -r FOLDER/gsutilnohash-WORK/* gs://do-not-delete-us-east4/"
    ;;
esac

# Clear out anything left over from previous runs.
rm time-$app.txt
sudo rm -rf /tmp/*
sudo rm -rf /mnt/disks/scratch/*
sudo rm -rf /dev/shm/*

# Returns a timestamp with 3 digits of nanoseconds.
timestamp() {
  date +'%s%N' | cut -b1-13
}

# Perform downloads.
for f in "${folders[@]}"
do
  for w in "${work[@]}"
  do
    # Skip and record '-' for the entry at this folder/workload.
    if [[ "$f" = "/dev/shm" && "$too_big" =~ .*"$w".* ]] || [[ "$skip" =~ .*"$w".* ]]; then
      echo "0" >> time-$app.txt
      continue
    fi
    # Clear cache.
    sync && echo 3 > sudo /proc/sys/vm/drop_caches
    # Make a working directory
    mkdir -v $f/$app-$w
    # Start the timer.
    start=$(timestamp)

    # This actually runs the command (with subsitutions).
    temp=${dl//WORK/$w}
    command=${temp//FOLDER/$f}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    bc <<< "scale = 3; ($end - $start) / 1000" >> time-$app.txt

    # Ensures TmpFS directory stays clear.
    rm -rf /dev/shm/*
  done
done

for f in "${folders[@]}"
do
  for w in "${work[@]}"
  do
    # Skip and record '-' for the entry at this folder/workload. Also skips
    # uploads for curl.
    if [[ "$f" = "/dev/shm" && "$too_big" =~ .*"$w".* ]] || [[ "$skip" =~ .*"$w".* ]] || [[ "$ul" = "" ]]; then
      echo "0" >> time-$app.txt
      continue
    fi
    # Clear cache.
    sync && echo 3 > sudo /proc/sys/vm/drop_caches
    # We re-use the download working directories, but for TmpFS runs we copy
    # over the working directory from the scratch disk.
    if [[ "$f" = "/dev/shm" ]]; then
      cp -r /mnt/disks/scratch/$app-$w /dev/shm/
    fi
    # Start the timer.
    start=$(timestamp)

    # This actually runs the command (with subsitutions).
    temp=${ul//WORK/$w}
    command=${temp//FOLDER/$f}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    bc <<< "scale = 3; ($end - $start) / 1000" >> time-$app.txt

    # Ensures TmpFS directory stays clear.
    rm -rf /dev/shm/*
  done
done


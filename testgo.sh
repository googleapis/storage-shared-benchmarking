#!/bin/bash
cores=$1
folders=( /mnt/disks/scratch )
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

go="CLOUDSDK_STORAGE_USE_CRC32C_BINARY=True gcloud -q alpha storage cp -r gs://do-not-delete-us-east4/WORK/ FOLDER"
py="CLOUDSDK_STORAGE_USE_CRC32C_BINARY=False gcloud -q alpha storage cp -r gs://do-not-delete-us-east4/WORK/ FOLDER"

# Clear out anything left over from previous runs.
rm time-go.txt
rm time-py.txt
sudo rm -rf /mnt/disks/scratch/*

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
      echo "0" >> time-go.txt
      continue
    fi
    # Clear cache.
    sync && echo 3 > sudo /proc/sys/vm/drop_caches

    # Start the timer.
    start=$(timestamp)

    # This actually runs the command (with subsitutions).
    temp=${go//WORK/$w}
    command=${temp//FOLDER/$f}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    bc <<< "scale = 3; ($end - $start) / 1000" >> time-go.txt
  done
done

for f in "${folders[@]}"
do
  for w in "${work[@]}"
  do
    # Skip and record '-' for the entry at this folder/workload. Also skips
    # uploads for curl.
    if [[ "$f" = "/dev/shm" && "$too_big" =~ .*"$w".* ]] || [[ "$skip" =~ .*"$w".* ]] || [[ "$ul" = "" ]]; then
      echo "0" >> time-py.txt
      continue
    fi
    # Clear cache.
    sync && echo 3 > sudo /proc/sys/vm/drop_caches
    # Start the timer.
    start=$(timestamp)

    # This actually runs the command (with subsitutions).
    temp=${py//WORK/$w}
    command=${temp//FOLDER/$f}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    bc <<< "scale = 3; ($end - $start) / 1000" >> time-py.txt
  done
done


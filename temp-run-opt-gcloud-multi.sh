#!/bin/bash
app=gs
cores=$1
work2=( 100x100M 100x10M 100x1M 100x1K 1000x10M 1000x1M 1000x1K )

# Multiple files: 6 proc, 4 threads (or 2 proc, 10 threads if <4 cores).
[[ $cores -lt 4 ]] && p2=2 || p2=16
[[ $cores -lt 4 ]] && t2=10 || t2=2
dl0="CLOUDSDK_PYTHON_SITEPACKAGES=1 gcloud alpha storage cp -r gs://do-not-delete-us-east4/WORK/* /mnt/disks/scratch/gs-WORK/"
dl1="CLOUDSDK_PYTHON_SITEPACKAGES=1 CLOUDSDK_STORAGE_PROCESS_COUNT=$p2 CLOUDSDK_STORAGE_THREAD_COUNT=$t2 gcloud alpha storage cp -r gs://do-not-delete-us-east4/WORK/* /mnt/disks/scratch/gs-WORK/"  

ul0="CLOUDSDK_PYTHON_SITEPACKAGES=1 CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M gcloud alpha storage cp -r /mnt/disks/scratch/gs-WORK gs://do-not-delete-opt-$1/"
ul1="CLOUDSDK_PYTHON_SITEPACKAGES=1 CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M CLOUDSDK_STORAGE_PROCESS_COUNT=$p2 CLOUDSDK_STORAGE_THREAD_COUNT=$t2 gcloud alpha storage cp -r /mnt/disks/scratch/gs-WORK gs://do-not-delete-opt-$1/"

# Clear out anything left over from previous runs.
rm time-opt-$app.txt
sudo rm -rf /mnt/disks/scratch/*

# Returns a timestamp with 3 digits of nanoseconds.
timestamp() {
  date +'%s%N' | cut -b1-13
}

# Drops all vm caches to attempt to isolate results.
clearCache() {
  sync && echo 3 > sudo /proc/sys/vm/drop_caches
}

# Arrays that will capture the results
declare -A dlDef
declare -A dlOpt
declare -A ulDef
declare -A ulOpt

# Perform multi-file downloads.
for w in "${work2[@]}"
do
  # Make a working directory
  mkdir -v /mnt/disks/scratch/$app-$w

  for i in {1..3}
  do
    # Matrix-like array index
    index="$w,$i"
    
    clearCache
    # Start the timer.
    start=$(timestamp)
    # Run the command with defaults
    command=${dl0//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command
    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    dlDef[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")

    clearCache
    # Start the timer (again).
    start=$(timestamp)
    # Run the optimized command
    command=${dl1//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command
    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    dlOpt[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")

    clearCache
    # Start the timer.
    start=$(timestamp)
    # Run the command with defaults
    command=${ul0//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command
    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    ulDef[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")

    clearCache
    # Start the timer (again).
    start=$(timestamp)
    # Run the optimized command
    command=${ul1//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command
    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    ulOpt[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")
  done
done

echo "operation,cores,workload,default_time1,default_time2,default_time3,opt_time1,opt_time2,opt_time3" >> time-opt-$app.txt

# Dump results to file
for i in "${!work2[@]}"
do
  w=${work2[$i]}
  echo "upload,$1,$w,${ulDef["$w,1"]},${ulDef["$w,2"]},${ulDef["$w,3"]},${ulOpt["$w,1"]},${ulOpt["$w,2"]},${ulOpt["$w,3"]}" >> time-opt-$app.txt
  echo "download,$1,$w,${dlDef["$w,1"]},${dlDef["$w,2"]},${dlDef["$w,3"]},${dlOpt["$w,1"]},${dlOpt["$w,2"]},${dlOpt["$w,3"]}" >> time-opt-$app.txt
done

gsutil -m cp time-opt-gs.txt gs://do-not-delete-us-east4/time-opt-$2/
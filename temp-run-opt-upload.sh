#!/bin/bash
app=$1
cores=$2
work1=( 1x10G 1x5G 1x1G 1x100M 1x10M 1x1M 1x1K )
work2=( 100x100M 100x10M 100x1M 100x1K 1000x10M 1000x1M 1000x1K )

# Download file commands.
ul0="" # Use defaults
ul1="" # Use best values for single files
ul2="" # Use best values for multiple files

# Set the commands for the various apps.
case "$app" in

  gs)
    # Single files:
    p1=8
    t1=1
    # Multiple files:
    p2=16
    t2=1
    #CLOUDSDK_STORAGE_CHECK_HASHES=never CLOUDSDK_STORAGE_PROCESS_COUNT=6 CLOUDSDK_STORAGE_THREAD_COUNT=4 CLOUDSDK_STORAGE_SLICED_OBJECT_DOWNLOAD_MAX_COMPONENTS=2 gcloud alpha storage cp -r gs://do-not-delete-us-east4/100x1M/* .
    ul0="CLOUDSDK_STORAGE_CHECK_HASHES=never CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M benchmarking/timeout.sh -t 60 gcloud alpha storage cp -r /mnt/disks/scratch/gs-WORK gs://do-not-delete-opt-$2/"
    ul1="CLOUDSDK_STORAGE_CHECK_HASHES=never CLOUDSDK_STORAGE_PROCESS_COUNT=$p1 CLOUDSDK_STORAGE_THREAD_COUNT=$t1 CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M benchmarking/timeout.sh -t 60 gcloud alpha storage cp -r /mnt/disks/scratch/gs-WORK gs://do-not-delete-opt-$2/"
    ul2="CLOUDSDK_STORAGE_CHECK_HASHES=never CLOUDSDK_STORAGE_PROCESS_COUNT=$p2 CLOUDSDK_STORAGE_THREAD_COUNT=$t2 CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M benchmarking/timeout.sh -t 60 gcloud alpha storage cp -r /mnt/disks/scratch/gs-WORK gs://do-not-delete-opt-$2/"  
    ;;

  gsutil)
    # Single files: 8 proc, 1 thread (or 4 proc, 1 thread if <4 cores).
    [[ $cores -lt 4 ]] && p1=4 || p1=8
    b=".boto-sliced-optimized"
    # Multiple files: 8 proc, 2 thread (or 4 proc, 2 threads if <4 cores).
    [[ $cores -lt 4 ]] && p2=4 || p2=8
    [[ $cores -lt 8 ]] && b=".boto-sliced-defaults" || b=".boto-sliced-optimized"
    # gsutil -m -o'GSUtil:check_hashes=never' -o'GSUtil:parallel_process_count=4' -o'GSUtil:parallel_thread_count=10' -o'GSUtil:sliced_object_download_max_components=8'  cp -r gs://do-not-delete-us-east4/WORK/* /mnt/disks/scratch/
    ul0="benchmarking/timeout.sh -t 60 gsutil -m -o'GSUtil:check_hashes=never' cp -r /mnt/disks/scratch/gsutil-WORK gs://do-not-delete-opt-$2/"
    ul1="BOTO_CONFIG=~/benchmarking/$b benchmarking/timeout.sh -t 60 gsutil -m -o'GSUtil:check_hashes=never' -o'GSUtil:parallel_process_count=$p1' -o'GSUtil:parallel_thread_count=1' -o'GSUtil:sliced_object_download_max_components=8'  cp -r /mnt/disks/scratch/gsutil-WORK gs://do-not-delete-opt-$2/"
    ul2="BOTO_CONFIG=~/benchmarking/$b benchmarking/timeout.sh -t 60 gsutil -m -o'GSUtil:check_hashes=never' -o'GSUtil:parallel_process_count=$p2' -o'GSUtil:parallel_thread_count=2' -o'GSUtil:sliced_object_download_max_components=8'  cp -r /mnt/disks/scratch/gsutil-WORK gs://do-not-delete-opt-$2/"
    ;;

esac

# Clear out anything left over from previous runs.
rm time-opt-$app.txt

# Returns a timestamp with 3 digits of nanoseconds.
timestamp() {
  date +'%s%N' | cut -b1-13
}

# Arrays that will capture the results
declare -A singDef
declare -A singOpt
declare -A multDef
declare -A multOpt

# Perform single file downloads.
for i in {1..3}
do
  for w in "${work1[@]}"
  do
    # Clear cache.
    sync && echo 3 > sudo /proc/sys/vm/drop_caches
    # Make a working directory
    mkdir -v /mnt/disks/scratch/$app-$w
    
    # Matrix-like array index
    index="$w,$i"
    
    # Start the timer.
    start=$(timestamp)
    
    # Run the command with defaults
    command=${ul0//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    singDef[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")

    # Clear cache.
    sync && echo 3 > sudo /proc/sys/vm/drop_caches

    # Start the timer (again).
    start=$(timestamp)

    # Run the optimized command
    command=${ul1//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    singOpt[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")
  done
done

# Perform single file downloads.
for i in {1..3}
do
  for w in "${work2[@]}"
  do
    # Clear cache.
    sync && echo 3 > sudo /proc/sys/vm/drop_caches

    # Make a working directory
    mkdir -v /mnt/disks/scratch/$app-$w

    # Matrix-like array index
    index="$w,$i"

    # Start the timer.
    start=$(timestamp)
    
    # Run the command with defaults
    command=${ul0//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    multDef[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")

    # Clear cache.
    sync && echo 3 > sudo /proc/sys/vm/drop_caches

    # Start the timer.
    start=$(timestamp)

    # This actually runs the command (with subsitutions).
    command=${ul2//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    multOpt[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")
  done
done

echo "cores,workload,default_time1,default_time2,default_time3,opt_time1,opt_time2,opt_time3" >> time-opt-$app.txt

# Dump results to file
for i in "${!work1[@]}"
do
  w=${work1[$i]}
  echo "$2,$w,${singDef["$w,1"]},${singDef["$w,2"]},${singDef["$w,3"]},${singOpt["$w,1"]},${singOpt["$w,2"]},${singOpt["$w,3"]}" >> time-opt-$app.txt
done
for i in "${!work2[@]}"
do
  w=${work2[$i]}
  echo "$2,$w,${multDef["$w,1"]},${multDef["$w,2"]},${multDef["$w,3"]},${multOpt["$w,1"]},${multOpt["$w,2"]},${multOpt["$w,3"]}" >> time-opt-$app.txt
done

gsutil -m cp time-opt-$app.txt gs://do-not-delete-us-east4/time-opt-$2/
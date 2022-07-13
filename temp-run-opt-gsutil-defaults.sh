#!/bin/bash
app=gsutil
cores=$1
work1=( 1x10G 1x5G 1x1G 1x100M 1x10M 1x1M 1x1K )
work2=( 100x100M 100x10M 100x1M 100x1K 1000x10M 1000x1M 1000x1K )

# gsutil -m -o'GSUtil:check_hashes=never' -o'GSUtil:parallel_process_count=4' -o'GSUtil:parallel_thread_count=10' -o'GSUtil:sliced_object_download_max_components=8'  cp -r gs://do-not-delete-us-east4/WORK/* /mnt/disks/scratch/
dl0="gsutil -m -o'GSUtil:check_hashes=never' cp -r gs://do-not-delete-us-east4/WORK/* /mnt/disks/scratch/gsutil-WORK/"

# Move .boto file
mv ~/.boto ~/.boto-backup

# Clear out anything left over from previous runs.
rm time-opt-$app.txt

# Returns a timestamp with 3 digits of nanoseconds.
timestamp() {
  date +'%s%N' | cut -b1-13
}

# Arrays that will capture the results
declare -A singDef
declare -A multDef

# Perform single file downloads.
for i in {1..3}
do
  for w in "${work1[@]}"
  do
    # Clear cache.
    echo 3 > sudo /proc/sys/vm/drop_caches
    
    # Matrix-like array index
    index="$w,$i"
    
    # Start the timer.
    start=$(timestamp)
    
    # Run the command with defaults
    command=${dl0//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    singDef[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")
  done
done

# Perform single file downloads.
for i in {1..3}
do
  for w in "${work2[@]}"
  do
    # Clear cache.
    echo 3 > sudo /proc/sys/vm/drop_caches

    # Matrix-like array index
    index="$w,$i"

    # Start the timer.
    start=$(timestamp)
    
    # Run the command with defaults
    command=${dl0//WORK/$w}
    echo '---------------------------------------------------------'
    echo $command
    eval $command

    # End the timer and record elapsed time in <seconds>.<nanos>.
    end=$(timestamp)
    multDef[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")
  done
done

echo "cores,workload,default_time1,default_time2,default_time3" >> time-opt-$app.txt

# Dump results to file
for i in "${!work1[@]}"
do
  w=${work1[$i]}
  echo "$1,$w,${singDef["$w,1"]},${singDef["$w,2"]},${singDef["$w,3"]}" >> time-opt-$app.txt
done
for i in "${!work2[@]}"
do
  w=${work2[$i]}
  echo "$1,$w,${multDef["$w,1"]},${multDef["$w,2"]},${multDef["$w,3"]}" >> time-opt-$app.txt
done

gsutil -m cp time-opt-$app.txt gs://do-not-delete-us-east4/time-opt-$1/
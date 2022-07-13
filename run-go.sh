#!/bin/bash
# Runs benchmarking trial for gcloud storage blog post.

folder="/mnt/disks/scratch"
apps=( go py )
work=( 1x10G 1x5G 1x1G 1x100M 1x10M 1x1M 1x1K 100x100M 100x10M 100x1M 100x1K 1000x10M 1000x1M 1000x1K )
iterations=10

# Returns a timestamp with 3 digits of nanoseconds.
timestamp() {
  date +'%s%N' | cut -b1-13
}

clearCache() {
  sync && echo 3 > sudo /proc/sys/vm/drop_caches
}

# Arrays that will capture the results.
declare -A downloads

for app in "${apps[@]}"
do
  # Download/upload commands.
  dl=""
  ul=""
  # Set the commands for the various apps.
  case "$app" in
    go)
      dl="CLOUDSDK_STORAGE_USE_CRC32C_BINARY=True gcloud -q alpha storage cp -r gs://do-not-delete-us-east4/WORK/ FOLDER"
      ;;

    py)
      dl="CLOUDSDK_STORAGE_USE_CRC32C_BINARY=False gcloud -q alpha storage cp -r gs://do-not-delete-us-east4/WORK/ FOLDER"
      ;;
  esac

  # Perform transfers.
  for w in "${work[@]}"
  do
    for (( i=1; i<=$iterations; i++ ))
    do
      index="$app,$w,$i"

      # Download logic.
      clearCache
      # Start the timer.
      start=$(timestamp)

      # This actually runs the command (with subsitutions).
      temp=${dl//WORK/$w}
      command=${temp//FOLDER/$folder}
      echo '---------------------------------------------------------'
      echo $command
      eval $command

      # End the timer and record elapsed time in <seconds>.<nanos>.
      end=$(timestamp)
      downloads[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")
    done
  done
done

rm go-benchmark.txt
headersGo=""
headersPy=""
for (( i=1; i<=$iterations; i++ ))
do
  headersGo+=",go_time$i"
  headersPy+=",py_time$i"
done
echo "operation,workload$headersGo$headersPy" >> go-benchmark.txt
for w in "${work[@]}"
do
  dlGo=""
  dlPy=""
  for (( i=1; i<=$iterations; i++ ))
  do
    dlGo+=",${downloads["go,$w,$i"]}"
    dlPy+=",${downloads["py,$w,$i"]}"
  done
  echo "download,$w$dlGo,$dlPy" >> go-benchmark.txt
done

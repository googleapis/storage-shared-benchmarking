#!/bin/bash
# Runs benchmarking trial for gcloud storage blog post.

folder="/mnt/disks/scratch"
apps=( gcsfast gs gsutil )
work=( 1x10G 100x100M )
iterations=3

# Returns a timestamp with 3 digits of nanoseconds.
timestamp() {
  date +'%s%N' | cut -b1-13
}

clearCache() {
  sync && echo 3 > sudo /proc/sys/vm/drop_caches
}

calcIterations() {
  # The difference between gcsfast and gcloud is very small, so we iterate more.
  if [[ "$1" = "1x10G" && "$2" != "gsutil" ]]; then
      iterations=20
  else
      iterations=3
  fi
}

# Arrays that will capture the results.
declare -A downloads
declare -A uploads

for app in "${apps[@]}"
do
  # Download/upload commands.
  dl=""
  ul=""
  # Which workflows should be skipped.
  skip=""
  # Set the commands for the various apps.
  case "$app" in
    gcsfast)
      skip="100x100M"
      dl="gcsfast download gs://do-not-delete-us-east4/WORK/file1.txt FOLDER/gcsfast-WORK/file1.txt"
      ul="gcsfast upload FOLDER/gcsfast-WORK/file1.txt gs://do-not-delete-us-east4/file1.txt"
      ;;

    gs)
      dl="CLOUDSDK_PYTHON_SITEPACKAGES=1 benchmarking/timeout.sh -t 500 gcloud alpha storage cp -r gs://do-not-delete-us-east4/WORK/* FOLDER/gs-WORK/"
      ul="CLOUDSDK_PYTHON_SITEPACKAGES=1 CLOUDSDK_STORAGE_PARALLEL_COMPOSITE_UPLOAD_THRESHOLD=150M benchmarking/timeout.sh -t 500 gcloud alpha storage cp -r FOLDER/gs-WORK/* gs://do-not-delete-us-east4/"
      ;;
    
    gsutil)
      dl="gsutil -m cp -r gs://do-not-delete-us-east4/WORK/* FOLDER/gsutil-WORK/"
      ul="gsutil -m cp -r FOLDER/gsutil-WORK/* gs://do-not-delete-us-east4/"
      ;;
  esac

  # Perform transfers.
  for w in "${work[@]}"
  do
    calcIterations "$w" "$app"
    for (( i=1; i<=$iterations; i++ ))
    do
      index="$app,$w,$i"

      # This allows certain workloads to be skipped.
      if [[ "$skip" =~ .*"$w".* ]]; then
        uploads[$index]=-
        downloads[$index]=-
        continue
      fi
      
      # Download logic.
      clearCache
      # Make a working directory
      mkdir -v $folder/$app-$w
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

      # Uploads don't need extensive testing (they aren't even close).
      if [[ $i -gt 3 ]]; then
        rm -rf $folder/$app-$w
        continue
      fi

      # Upload logic.
      clearCache
      # Start the timer.
      start=$(timestamp)

      # This actually runs the command (with subsitutions).
      temp=${ul//WORK/$w}
      command=${temp//FOLDER/$folder}
      echo '---------------------------------------------------------'
      echo $command
      eval $command
      
      # End the timer and record elapsed time in <seconds>.<nanos>.
      end=$(timestamp)
      uploads[$index]=$(bc <<< "scale = 3; ($end - $start) / 1000")

      # Clean up
      rm -rf $folder/$app-$w
    done
  done
done

rm blog-benchmark.txt
echo "operation,workload,gs_time,gsutil_time,gcsfast_time" >> blog-benchmark.txt
for w in "${work[@]}"
do
  for i in {1..3}
  do
    dlGs="${downloads["gs,$w,$i"]}"
    dlGsutil="${downloads["gsutil,$w,$i"]}"
    dlGcsfast="${downloads["gcsfast,$w,$i"]}"
    echo "download,$w,$dlGs,$dlGsutil,$dlGcsfast" >> blog-benchmark.txt
  done
  for i in {4..20}
  do
    dlGs="${downloads["gs,$w,$i"]}"
    dlGcsfast="${downloads["gcsfast,$w,$i"]}"
    echo "download,$w,$dlGs,-,$dlGcsfast" >> blog-benchmark.txt
  done
  for i in {1..3}
  do
    ulGs="${uploads["gs,$w,$i"]}"
    ulGsutil="${uploads["gsutil,$w,$i"]}"
    ulGcsfast="${uploads["gcsfast,$w,$i"]}"
    echo "upload,$w,$ulGs,$ulGsutil,$ulGcsfast" >> blog-benchmark.txt
  done
done
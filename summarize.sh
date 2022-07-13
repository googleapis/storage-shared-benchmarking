#!/bin/bash
cores=( 2 4 8 16 96 )
transport=( Download Upload)
apps=( gs gsnohash gsutil gsutilnohash aws gcsfast curl )
disks=( Boot Scratch TmpFS )
work=( 1x10G 1x5G 1x1G 1x100M 1x10M 1x1M 1x1K 100x100M 100x10M 100x1M 100x1K 1000x10M 1000x1M 1000x1K )

declare -A data

# Delete file to start with
rm time-summary.txt

# Read each line of each app result file and store it in an array
for c in "${cores[@]}"
do
  for a in "${apps[@]}"
  do
    filename="time-$c/time-$a.txt"
    i=0
    while read line; do
      echo "recording $c,$a,$i"
      data["$c,$a,$i"]=$line
      i=$((i+1))
    done < $filename
  done
done

for c in "${cores[@]}"
do
  i=0
  for t in "${transport[@]}"
  do
    for d in "${disks[@]}"
    do
      for w in "${work[@]}"
      do
        echo "writing $c,$t,$d,$w"
        echo "$c,$t,$d,$w,${data["$c,gs,$i"]},${data["$c,gsnohash,$i"]},${data["$c,gsutil,$i"]},${data["$c,gsutilnohash,$i"]},${data["$c,aws,$i"]},${data["$c,gcsfast,$i"]},${data["$c,curl,$i"]}" >> time-summary.txt
        i=$((i+1))
      done
    done
  done
done

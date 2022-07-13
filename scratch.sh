#!/bin/bash
lsblk
sudo mkfs.ext4 -F /dev/nvme0n1
sudo mkdir -p /mnt/disks/scratch
sudo mount /dev/nvme0n1 /mnt/disks/scratch
sudo chmod a+w /mnt/disks/scratch

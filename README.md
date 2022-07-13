# Gcloud Storage Benchmarking Framework

## Set up a new VM

Create each VM with:
- 100GiB balanced persistent disk
- Ubuntu 20.10
- Service account: benchmarking@bigstore-gsutil-testing.iam.gserviceaccount.com
- NVMe scratch disk (local SSD)

```
gcloud compute instances create instance-1 --project=spec-test-ruby-samples --zone=us-west2-a --machine-type=c2-standard-4 --network-interface=network-tier=PREMIUM,subnet=default --maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=787021104993-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/cloud-platform --create-disk=auto-delete=yes,boot=yes,device-name=instance-1,image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20220712a,mode=rw,size=100,type=projects/spec-test-ruby-samples/zones/us-west2-a/diskTypes/pd-balanced --local-ssd=interface=NVME --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any
```

Once you SSH into the box, start by cloning this repo into the VM home
directory:
```
$ gcloud source repos clone benchmarking --project=bigstore-gsutil-testing
```

Then run:
- `benchmarking/install.sh` to set up the peer applications (you will need AWS access keys)
- `benchmarking/gcloud.sh` to set up a custom instance of gcloud
- `benchmarking/scratch.sh` to set up the scratch disk (you did add a scratch disk, right?)

## Run a test

```
$ benchmarking/run.sh <APP> <MACHINE-SIZE>
```
**APP**
- `aws`
- `curl`
- `gcsfast`
- `gs`
- `gsnohash`
- `gsutil`
- `gsutilnohash`

**MACHINE-SIZE**
- `small`
- `medium`
- `large`

To run benchmarking on all of the above apps use:

```
$ benchmarking/run-all.sh <MACHINE-SIZE>
```

## Update with the latest code

In google3 run the following:
```
$ ./cloud/sdk/release/build_and_push_to.sh /bigstore/do-not-delete-tt
```
Then run the following on the VM:
```
$ gcloud components update
```
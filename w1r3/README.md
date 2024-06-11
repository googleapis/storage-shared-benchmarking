# Developing and Deploying the W1R3 benchmarks

This document describes how to deploy and develop the W1R3 benchmarks. The
motivation and objectives of these benchmarks are out of scope, please see the
design documents for details.

## Running locally

The benchmarks can be run locally, from the command line. In all these examples
we will assume you have set the `PROJECT_ID` shell variable to a project you
use for development, and `BUCKET_NAME` to the name of a bucket enabled for gRPC.

Please do not use the "production" project, we want to minimize the chances of
losing historical data, or adding noise to it.

The metrics will be published to `PROJECT_ID`. You will use the
[Metrics Explorer](https://console.google.com/monitoring/metrics-explorer) to
see the metric results.

Note that the `GRPC+DP` transport is disabled, as it is unlikely to work from
your workstation.

- C++
  ```shell
  cmake --build .build/ && .build/w1r3/cpp/w1r3 \
    --project-id=${PROJECT_ID} \
    --bucket=${BUCKET_NAME} \
    --transport=GRPC+CFE --transport=JSON \
    --iterations=10000
  ```
- Go
  ```shell
  go -C w1r3/go build && ./w1r3/go/w1r3 \
    -project-id=${PROJECT_ID} \
    -bucket=${BUCKET_NAME} \
    -transport GRPC+CFE -transport JSON \
    -iterations 10000
  ```
- Java
  ```shell
  env -C w1r3/java/ mvn package && \
  java -jar w1r3/java/target/w1r3-0.0.1-SNAPSHOT.jar \
      -project-id ${PROJECT_ID} \
      -bucket ${BUCKET_NAME} \
      -transport GRPC+CFE -transport JSON \
      -iterations 10000
  ```

## Updating the existing deployments

New versions of the benchmarks are not (yet) automatically deployed. You can
force a deployment using:

- C++
  ```shell
  gcloud beta compute instance-groups managed  --project=storage-sdk-prober-project rolling-action restart --region=us-central1 w1r3-cpp-runner-v1
  ```
- Go
  ```shell
  gcloud beta compute instance-groups managed  --project=storage-sdk-prober-project rolling-action restart --region=us-central1 w1r3-go-runner-v1
  ```
- Java
  ```shell
  gcloud beta compute instance-groups managed  --project=storage-sdk-prober-project rolling-action restart --region=us-central1 w1r3-java-runner-v1
  ```

## Updating the infrastructure

We use terraform to update the infrastructure. This is not the right place to
give you a full introduction to terraform, but the following commands should
help. The commands assume you have `terraform` installed, verify using:

```sh
terraform --version
```

You should expect something like:

```
Terraform v1.8.3
on linux_amd64
```

Initialize the terraform modules 

```shell
cd w1r3/infra/
terraform init
```

You should see something like:

```console
Initializing the backend...
Initializing modules...

Initializing provider plugins...
- Reusing previous version of hashicorp/google from the dependency lock file
- Using previously-installed hashicorp/google v5.29.1

Terraform has been successfully initialized!
... ... [informational messages omitted] ... ...
```

You then create a plan to update the deployment:

```shell
terraform plan -out=/tmp/plan.out
```

If there are no changes you will see something like:

```console
... ... [informational messages omitted] ... ...

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
```

If there are changes you will see a long description of what would change. You
should review the changes, and then apply them using:

```shell
terraform apply /tmp/plan.out
```

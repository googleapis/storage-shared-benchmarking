#!/usr/bin/env python
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""The Python version of the W1R3 benchmark."""

import argparse
import random
import resource
import sys
import time
import uuid

import google.cloud.storage as storage
import google.protobuf
import grpc
import opentelemetry.metrics as metrics
import opentelemetry.sdk.metrics as sdkmetrics
import opentelemetry.sdk.metrics.view as view
import opentelemetry.sdk.trace as sdktrace
import opentelemetry.trace as trace
import requests
from opentelemetry.exporter.cloud_monitoring import CloudMonitoringMetricsExporter
from opentelemetry.exporter.cloud_trace import CloudTraceSpanExporter
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.resourcedetector.gcp_resource_detector import (
    GoogleCloudResourceDetector,
)
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# You can optionally pass a custom TracerProvider to instrument().
response = requests.get(url="https://www.example.org/")


def main():
    args = parse_args()
    instance = str(uuid.uuid4())
    print("## Starting continuous GCS Python SDK benchmark")
    print(f"# object-sizes: {args.object_size}")
    print(f"# transports: {args.transport}")
    print(f"# project-id: {args.project_id}")
    print(f"# bucket: {args.bucket}")
    print(f"# deployment: {args.deployment}")
    print(f"# instance: {instance}")
    print(f"# Benchmark Version: {_SSB_W1R3_VERSION}")
    print(f"# Python Version: {sys.version}")
    print(f"# Python SDK Version: {storage.__version__}")
    print(f"# gRPC Version: {grpc.__version__}")
    print(f"# Protobuf Version: {google.protobuf.__version__}")
    print(f"# HTTP Client Version: {requests.__version__}")

    tracer = configure_trace_exporter(args)
    (meter_provider, meter) = configure_metrics_exporter(instance, args)

    # Instrument Python's `requests` library to generate spans.
    RequestsInstrumentor().instrument()

    clients = make_clients(args)
    prng = random.Random()
    prng.seed()
    random_data = bytes([prng.randint(0, 255) for _ in range(0, max(args.object_size))])

    worker(clients, instance, prng, random_data, tracer, meter, args)


def worker(
    clients,
    instance,
    prng,
    random_data,
    tracer: sdktrace.Tracer,
    meter,
    args: argparse.Namespace,
):
    latency = meter.create_histogram(
        _LATENCY_HISTOGRAM_NAME,
        unit=_LATENCY_HISTOGRAM_UNIT,
        description=_LATENCY_HISTOGRAM_DESCRIPTION,
    )
    cpu = meter.create_histogram(
        _CPU_HISTOGRAM_NAME,
        unit=_CPU_HISTOGRAM_UNIT,
        description=_CPU_HISTOGRAM_DESCRIPTION,
    )

    for i in range(args.iterations):
        (transport_name, client) = prng.choice(clients)
        object_size = prng.choice(args.object_size)
        object_name = str(uuid.uuid4())

        common_attributes = {
            "ssb.language": "python",
            "ssb.object-size": object_size,
            "ssb.transport": transport_name,
            "ssb.deployment": args.deployment,
            "ssb.instance": instance,
            "ssb.version": _SSB_W1R3_VERSION,
            "ssb.version.sdk": storage.__version__,
            "ssb.version.grpc": grpc.__version__,
            "ssb.version.protobuf": google.protobuf.__version__,
            "ssb.version.http-client": requests.__version__,
        }
        span_attributes = (
            dict(trace.get_tracer_provider().resource.attributes) | common_attributes
        )

        with tracer.start_as_current_span(
            "ssb::iteration", attributes=span_attributes | {"ssb.iteration": i}
        ):
            # The magic number is the value hardcoded in the storage.Blob
            # implementation.
            upload_op = _SINGLE_SHOT if object_size <= 8 * 1024 * 1024 else _RESUMABLE
            with tracer.start_as_current_span(
                "ssb::upload", attributes=span_attributes | {"ssb.op": upload_op}
            ) as upload_span:
                bucket = client.bucket(args.bucket)
                try:
                    start = time.monotonic_ns()
                    cpu_start = cpu_now()
                    blob = bucket.blob(object_name)
                    blob.upload_from_string(
                        random_data[0 : min(object_size, len(random_data))],
                        if_generation_match=0,
                    )
                    cpu_usage = cpu_delta(cpu_start)
                    elapsed = time.monotonic_ns() - start
                    latency.record(
                        elapsed / float(_NANOS_PER_SECOND),
                        common_attributes | {"ssb.op": upload_op},
                    )
                    cpu.record(
                        cpu_usage * _NANOS_PER_SECOND / object_size,
                        common_attributes | {"ssb.op": upload_op},
                    )
                except Exception as ex:
                    upload_span.record_exception(ex)
                    upload_span.set_status(trace.StatusCode.ERROR)
                    continue
            for r in range(3):
                op_name = f"READ[{r}]"
                with tracer.start_as_current_span(
                    "ssb::download", attributes=span_attributes | {"ssb.op": op_name}
                ) as download_span:
                    try:
                        start = time.monotonic_ns()
                        cpu_start = cpu_now()
                        _ = blob.download_as_bytes()
                        cpu_usage = cpu_delta(cpu_start)
                        elapsed = time.monotonic_ns() - start
                        latency.record(
                            elapsed / float(_NANOS_PER_SECOND),
                            common_attributes | {"ssb.op": op_name},
                        )
                        cpu.record(
                            cpu_usage * _NANOS_PER_SECOND / object_size,
                            common_attributes | {"ssb.op": op_name},
                        )
                    except Exception as ex:
                        download_span.record_exception(ex)
                        download_span.set_status(trace.StatusCode.ERROR)
            try:
                blob.delete()
            except Exception:
                pass


def cpu_now() -> float:
    """Returns the current CPU usage (user and system) in floating point seconds."""
    ru = resource.getrusage(resource.RUSAGE_SELF)
    return ru.ru_utime + ru.ru_stime


def cpu_delta(start) -> float:
    return cpu_now() - start


def meter_resource(instance: str, args: argparse.Namespace) -> Resource:
    detected = dict(GoogleCloudResourceDetector().detect().attributes)
    attributes = {
        "cloud.account.id": args.project_id,
        "service.namespace": "default",
        "service.name": "w1r3",
        "service.instance.id": instance,
    }
    if "cloud.zone" in detected:
        # The resource detector detects "cloud.zone", but the exporter maps
        # "cloud.availability_zone" to the generic task location :shrug:
        attributes["cloud.availability_zone"] = detected["cloud.zone"]
    elif "cloud.region" in detected:
        attributes["cloud.region"] = detected["cloud.region"]
    return Resource.create(attributes)


def configure_trace_exporter(args: argparse.Namespace):
    trace_provider = sdktrace.TracerProvider(
        sampler=sdktrace.sampling.TraceIdRatioBased(args.tracing_rate),
        resource=GoogleCloudResourceDetector().detect(),
    )
    trace_exporter = CloudTraceSpanExporter(project_id=args.project_id)
    trace_provider.add_span_processor(
        BatchSpanProcessor(trace_exporter, max_export_batch_size=100)
    )
    trace.set_tracer_provider(trace_provider)
    return trace_provider.get_tracer(__name__)


def configure_metrics_exporter(instance: str, args: argparse.Namespace):
    histogram_view = view.View(
        instrument_name=_LATENCY_HISTOGRAM_NAME,
        instrument_unit=_LATENCY_HISTOGRAM_UNIT,
        meter_name=__name__,
        aggregation=view.ExplicitBucketHistogramAggregation(make_latency_boundaries()),
    )
    cpu_view = view.View(
        instrument_name=_CPU_HISTOGRAM_NAME,
        instrument_unit=_CPU_HISTOGRAM_UNIT,
        meter_name=__name__,
        aggregation=view.ExplicitBucketHistogramAggregation(make_cpu_boundaries()),
    )
    meter_provider = sdkmetrics.MeterProvider(
        metric_readers=[
            PeriodicExportingMetricReader(
                CloudMonitoringMetricsExporter(project_id=args.project_id),
                export_interval_millis=60 * 1000,
            ),
        ],
        resource=meter_resource(instance, args),
        views=[histogram_view, cpu_view],
    )
    return (meter_provider, meter_provider.get_meter(__name__))


def make_latency_boundaries():
    # Cloud Monitoring only supports up to 200 buckets per histogram, we have to
    # choose them carefully. The measurement values will be in floating point
    # seconds. We perform all computations in integer milliseconds.
    boundaries = []
    boundary = 0
    increment = 2
    # For the first 100ms use 2ms buckets. We need higher resolution in this
    # range for small uploads and downloads.
    for _ in range(0, 50):
        boundaries.append(boundary / 1000.0)
        boundary += increment
    # The remaining buckets are 10ms wide, and then 20ms, and so forth. We stop
    # at 300s (5 minutes) because any latency over that is too high for this
    # benchmark.
    boundary = 100
    increment = 10
    for i in range(0, 150):
        if boundary > 300_000:
            break
        boundaries.append(boundary / 1000.0)
        if i != 0 and i % 10 == 0:
            increment = 2 * increment
        boundary = boundary + increment
    return boundaries


def make_cpu_boundaries():
    # Cloud Monitoring only supports up to 200 buckets per histogram, we have to
    # choose them carefully. The measurement values will be in floating point
    # nanoseconds/By.
    boundaries = []
    boundary = 0
    increment = 0.1
    for i in range(0, 200):
        boundaries.append(boundary)
        if i != 0 and i % 10 == 0:
            increment = 2 * increment
        boundary += increment
    return boundaries


def make_clients(args: argparse.Namespace) -> list[tuple[str, storage.Client]]:
    clients = []
    for t in args.transport:
        if t == "JSON":
            clients.append((t, storage.Client(project=args.project_id)))
        else:
            raise "Unkown transport %s" % t
    return clients


def _get_git_hash() -> str:
    try:
        import git

        repo = git.Repo(search_parent_directories=True)
        return repo.head.object.hexsha
    except:
        return "unknown"


_NANOS_PER_SECOND = 1_000_000_000
_SSB_W1R3_VERSION = _get_git_hash()
_SINGLE_SHOT = "SINGLE-SHOT"
_RESUMABLE = "RESUMABLE"
_JSON = "JSON"
_GRPC_CFE = "GRPC+CFE"
_GRPC_DP = "GRPC+DP"
_LATENCY_HISTOGRAM_NAME = "ssb/w1r3/latency"
_LATENCY_HISTOGRAM_DESCRIPTION = "Operation latency as measured by the benchmark."
_LATENCY_HISTOGRAM_UNIT = "s"
_CPU_HISTOGRAM_NAME = "ssb/w1r3/cpu"
_CPU_HISTOGRAM_DESCRIPTION = "CPU usage per byte as measured by the benchmark."
_CPU_HISTOGRAM_UNIT = "ns/By{CPU}"
_DEFAULT_ITERATIONS = 1_000_000
_DEFAULT_SAMPLE_RATE = 0.05


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=(__doc__))
    parser.add_argument(
        "--project-id",
        action="store",
        required=True,
        help="the GCP project used by the benchmark.",
    )
    parser.add_argument(
        "--bucket",
        action="store",
        required=True,
        help="the Google Cloud Storage bucket used by the benchmark.",
    )
    parser.add_argument(
        "--object-size",
        nargs="+",
        type=int,
        default=[100000, 2 * 1024 * 1024, 100 * 1000 * 1000],
        help="the object sizes.",
    )
    parser.add_argument(
        "--transport",
        nargs="+",
        type=str,
        default=[_JSON],
        help="the transports used by the benchmark.",
    )
    parser.add_argument(
        "--deployment",
        action="store",
        default="development",
        help="the environment where the benchmark is deployed (e.g. GKE, MIG, GCE).",
    )
    parser.add_argument(
        "--iterations",
        action="store",
        default=_DEFAULT_ITERATIONS,
        type=int,
        help="the number of iterations run by the benchmark.",
    )
    parser.add_argument(
        "--tracing-rate",
        action="store",
        default=_DEFAULT_SAMPLE_RATE,
        type=float,
        help="the ratio of traces randomly sampled for upload.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    main()

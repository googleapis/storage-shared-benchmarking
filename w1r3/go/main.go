// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"os"
	"runtime/debug"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"cloud.google.com/go/profiler"
	"cloud.google.com/go/storage"
	"github.com/google/uuid"

	expmetric "github.com/GoogleCloudPlatform/opentelemetry-operations-go/exporter/metric"
	exptrace "github.com/GoogleCloudPlatform/opentelemetry-operations-go/exporter/trace"
	"go.opentelemetry.io/contrib/detectors/gcp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"

	// debugging

	// Install google-c2p resolver, which is required for direct path.
	_ "google.golang.org/grpc/xds/googledirectpath"
	// Install RLS load balancer policy, which is needed for gRPC RLS.
	_ "google.golang.org/grpc/balancer/rls"
)

const (
	JSON              = "JSON"
	GRPC_CFE          = "GRPC+CFE"
	GRPC_DP           = "GRPC+DP"
	singleShot        = "SINGLE-SHOT"
	resumable         = "RESUMABLE"
	KB                = 1000
	MB                = 1000 * KB
	KiB               = 1024
	MiB               = 1024 * KiB
	appName           = "w1r3"
	defaultSampleRate = 0.05
)

func main() {
	// Enable OTEL exemplars, they are still experimental in Go.
	if err := os.Setenv("OTEL_GO_X_EXEMPLAR", "true"); err != nil {
		log.Fatalf("error setting OTEL_GO_X_EXEMPLAR: %v", err)
	}

	var projectID = flag.String("project-id", "", "the Google Cloud Platform project")
	var bucket = flag.String("bucket", "", "the bucket used by the benchmark")
	var deployment = flag.String("deployment", "development", "where is the benchmark running. For example: development, GKE, GCE")
	var iterations = flag.Int("iterations", 1_000_000, "how many iterations to run")
	var workers = flag.Int("workers", 1, "the number of concurrent threads running the benchmark")
	var transportArgs stringFlags
	flag.Var(&transportArgs, "transport", "the transports (JSON, GRPC+CFE, GRPC+DP) used by the benchmark")
	var uploaderArgs stringFlags
	flag.Var(&uploaderArgs, "uploader", "the uploaders (SINGLE-SHOT, RESUMABLE) used by the benchmark")
	var objectSizes intFlags
	flag.Var(&objectSizes, "object-size", "the object sizes used by the benchmark")
	var tracingRate = flag.Float64("tracing-rate", defaultSampleRate, "the sample rate for traces")
	var profileVersion = flag.String("profile-version", benchmarkVersion(), "a version to identify in Cloud Profiler")
	flag.Parse()

	if *projectID == "" {
		flag.Usage()
		log.Fatal("-project-id is required")
	}
	if *bucket == "" {
		flag.Usage()
		log.Fatal("-bucket is required")
	}
	if len(transportArgs) == 0 {
		transportArgs = append(transportArgs, JSON, GRPC_CFE, GRPC_DP)
	}
	if len(uploaderArgs) == 0 {
		uploaderArgs = append(uploaderArgs, singleShot, resumable)
	}
	if len(objectSizes) == 0 {
		objectSizes = append(objectSizes, 100*KB, 2*MiB, 100*MB)
	}

	log.Print("## Starting continuous GCS Go SDK benchmark")
	instance, err := uuid.NewRandom()
	if err != nil {
		log.Fatalf("Cannot create instance name %v", err)
	}

	ctx := context.Background()
	cleanupProfiler := enableProfiler(*projectID, *deployment, *profileVersion)
	defer cleanupProfiler()
	cleanupTracing := enableTracing(ctx, *tracingRate, *projectID)
	defer cleanupTracing()
	cleanupMeter := enableMeter(ctx, *projectID, instance.String())
	defer cleanupMeter()

	transports := makeTransports(ctx, transportArgs)
	closeTransports := func() {
		for _, t := range transports {
			t.client.Close()
		}
	}
	defer closeTransports()

	uploaders := makeUploaders(uploaderArgs)

	versions := make(map[string]string)
	bi, ok := debug.ReadBuildInfo()
	if !ok {
		log.Fatal("Failed to read build info")
	}
	for _, dep := range bi.Deps {
		versions[dep.Path] = dep.Version
	}

	log.Printf("# object-sizes: %v", objectSizes)
	log.Printf("# transports: %v", transportArgs)
	log.Printf("# uploaders: %v", uploaderArgs)
	log.Printf("# project-id: %s", *projectID)
	log.Printf("# bucket: %s", *bucket)
	log.Printf("# deployment: %s", *deployment)
	log.Printf("# instance: %s", instance.String())
	log.Printf("# Benchmark Version: %s", benchmarkVersion())
	log.Printf("# Go SDK Version: %s", versions["cloud.google.com/go/storage"])
	log.Printf("# gRPC Version: %s", versions["google.golang.org/grpc"])
	log.Printf("# Protobuf Version: %s", versions["google.golang.org/protobuf"])
	log.Printf("# Tracing Rate: %f", *tracingRate)
	log.Printf("# Version for Profiler: %s", *profileVersion)

	config := Config{
		transports:  transports,
		uploaders:   uploaders,
		objectSizes: objectSizes,
		bucketName:  *bucket,
		deployment:  *deployment,
		instance:    instance.String(),
		versions:    versions,
		iterations:  *iterations,
	}

	var wg sync.WaitGroup
	launch := func() {
		defer wg.Done()
		worker(ctx, config)
	}

	wg.Add(*workers)
	for range *workers {
		go launch()
	}
	wg.Wait()
}

type Config struct {
	transports  []Transport
	uploaders   []Uploader
	objectSizes intFlags
	bucketName  string
	deployment  string
	instance    string
	versions    map[string]string
	iterations  int
}

func worker(ctx context.Context, config Config) {
	tracer := otel.GetTracerProvider().Tracer("")
	meter := otel.GetMeterProvider().Meter("")
	histogram, err := meter.Int64Histogram(
		"ssb/w1r3/latency",
		metric.WithDescription("The duration of task execution."),
		metric.WithUnit("ms"),
		metric.WithExplicitBucketBoundaries(histogramBoundaries()...),
	)
	if err != nil {
		log.Fatalf("Cannot create ssb/w1r3/latency histogram")
	}
	get_version := func(name string) string {
		v, ok := config.versions[name]
		if ok {
			return v
		}
		return "unknown"
	}

	data := make([]byte, slices.Max(config.objectSizes))
	rand.Read(data) // rand.Read() is deprecated, but good enough for this benchmark.
	for i := range config.iterations {
		id, err := uuid.NewRandom()
		if err != nil {
			continue
		}
		var objectName = id.String()
		var objectSize = config.objectSizes[rand.Intn(len(config.objectSizes))]
		var transport = config.transports[rand.Intn(len(config.transports))]
		if transport.client == nil {
			log.Fatalf("Iteration %d transport %s is nil", i, transport.name)
		}
		var uploader = config.uploaders[rand.Intn(len(config.uploaders))]

		commonAttributes := []attribute.KeyValue{
			attribute.String("ssb.language", "go"),
			attribute.Int64("ssb.object-size", objectSize),
			attribute.String("ssb.transport", transport.name),
			attribute.String("ssb.deployment", config.deployment),
			attribute.String("ssb.instance", config.instance),
			attribute.String("ssb.version", benchmarkVersion()),
			attribute.String("ssb.version.sdk", get_version("cloud.google.com/go/storage")),
			attribute.String("ssb.version.grpc", get_version("google.golang.org/grpc")),
			attribute.String("ssb.version.protobuf", get_version("google.golang.org/protobuf")),
			attribute.String("ssb.version.http", get_version("golang.org/x/net")),
		}

		spanContext, span := tracer.Start(
			ctx, "ssb::iteration", trace.WithAttributes(
				append([]attribute.KeyValue{attribute.Int("ssb.iteration", i)}, commonAttributes...)...))

		uploadContext, uploadSpan := tracer.Start(
			spanContext, "ssb::upload", trace.WithAttributes(
				append([]attribute.KeyValue{attribute.String("ssb.op", uploader.name)}, commonAttributes...)...))

		upload_start := time.Now()
		objectHandle, err := uploader.uploader(uploadContext, transport.client, config.bucketName, objectName, data[0:objectSize])
		if err != nil {
			uploadSpan.SetStatus(codes.Error, "error during upload")
			uploadSpan.RecordError(err)
			uploadSpan.End()
			span.End()
			continue
		}
		duration := time.Since(upload_start)
		histogram.Record(uploadContext, duration.Milliseconds(), metric.WithAttributes(
			append([]attribute.KeyValue{attribute.String("ssb.op", uploader.name)}, commonAttributes...)...))
		uploadSpan.End()

		discard := make([]byte, 2*MiB)
		for r := range 3 {
			op := fmt.Sprintf("READ[%d]", r)
			downloadContext, downloadSpan := tracer.Start(
				spanContext, "ssb::download", trace.WithAttributes(
					append([]attribute.KeyValue{attribute.String("ssb.op", op)}, commonAttributes...)...))

			download_start := time.Now()
			objectReader, err := objectHandle.NewReader(downloadContext)
			if err != nil {
				log.Printf("Error in ssb::upload %d transport %s size %d: %v", i, transport.name, objectSize, err)
				downloadSpan.SetStatus(codes.Error, "error while opening reader")
				downloadSpan.RecordError(err)
				downloadSpan.End()
				continue
			}
			for {
				_, err := objectReader.Read(discard)
				if err != nil {
					break
				}
			}
			err = objectReader.Close()
			if err != nil {
				downloadSpan.SetStatus(codes.Error, "error while closing reader")
				downloadSpan.RecordError(err)
			}
			downloadSpan.End()
			duration := time.Since(download_start)
			histogram.Record(downloadContext, duration.Milliseconds(), metric.WithAttributes(
				append([]attribute.KeyValue{attribute.String("ssb.op", op)}, commonAttributes...)...))
		}

		d := objectHandle.Retryer(storage.WithPolicy(storage.RetryAlways))
		d.Delete(spanContext)
		span.End()
	}
}

type Uploader struct {
	name     string
	uploader func(ctx context.Context, client *storage.Client, bucketName string, objectName string, data []byte) (*storage.ObjectHandle, error)
}

func singleShotUpload(ctx context.Context, client *storage.Client, bucketName string, objectName string, data []byte) (*storage.ObjectHandle, error) {
	bucket := client.Bucket(bucketName)
	o := bucket.Object(objectName)
	objectWriter := o.If(storage.Conditions{DoesNotExist: true}).NewWriter(ctx)
	objectWriter.ChunkSize = len(data) + 1
	if _, err := io.Copy(objectWriter, bytes.NewBuffer(data)); err != nil {
		return o, err
	}
	return o, objectWriter.Close()
}

func resumableUpload(ctx context.Context, client *storage.Client, bucketName string, objectName string, data []byte) (*storage.ObjectHandle, error) {
	bucket := client.Bucket(bucketName)
	o := bucket.Object(objectName)
	objectWriter := o.If(storage.Conditions{DoesNotExist: true}).NewWriter(ctx)
	objectWriter.ChunkSize = 2 * MiB
	offset := 0
	for offset < len(data) {
		n := min(objectWriter.ChunkSize, len(data)-offset)
		if _, err := objectWriter.Write(data[offset : offset+n]); err != nil {
			return o, err
		}
		offset += n
	}
	return o, objectWriter.Close()
}

func makeUploaders(names stringFlags) []Uploader {
	var uploaders = make([]Uploader, 0)
	for _, name := range names {
		if name == singleShot {
			uploaders = append(uploaders, Uploader{singleShot, singleShotUpload})
		} else if name == resumable {
			uploaders = append(uploaders, Uploader{resumable, resumableUpload})
		} else {
			log.Fatalf("unknown uploader name %v", name)
		}
	}
	return uploaders
}

type Transport struct {
	name   string
	client *storage.Client
}

func makeTransports(ctx context.Context, flags stringFlags) []Transport {
	var transports = make([]Transport, 0)
	for _, transport := range flags {
		if transport == JSON {
			client, err := storage.NewClient(ctx)
			if err != nil {
				log.Fatalf("storage.NewClient for %s: %v", transport, err)
			}
			transports = append(transports, Transport{transport, client})
		} else if transport == GRPC_CFE {
			client, err := storage.NewGRPCClient(ctx)
			if err != nil {
				log.Fatalf("storage.NewGRPCClient for %v: %v", transport, err)
			}
			transports = append(transports, Transport{transport, client})
		} else if transport == GRPC_DP {
			const xdsEnvVar = "GOOGLE_CLOUD_ENABLE_DIRECT_PATH_XDS"
			if err := os.Setenv(xdsEnvVar, "true"); err != nil {
				log.Fatalf("error setting %s: %v", xdsEnvVar, err)
			}
			client, err := storage.NewGRPCClient(ctx)
			if err != nil {
				log.Fatalf("storage.NewGRPCClient for %v: %v", transport, err)
			}
			transports = append(transports, Transport{transport, client})
			if err := os.Unsetenv(xdsEnvVar); err != nil {
				log.Fatalf("error unsetting %s: %v", xdsEnvVar, err)
			}
		} else {
			log.Fatalf("unknown transport %v", transport)
		}
	}
	return transports
}

// enableTracing turns on Open Telemetry tracing with export to Cloud Trace.
func enableTracing(ctx context.Context, sampleRate float64, projectID string) func() {
	exporter, err := exptrace.New(exptrace.WithProjectID(projectID))
	if err != nil {
		log.Fatalf("exptrace.New: %v", err)
	}

	// Identify your application using resource detection
	res, err := resource.New(ctx,
		// Use the GCP resource detector to detect information about the GCP platform
		resource.WithDetectors(gcp.NewDetector()),
		// Keep the default detectors
		resource.WithTelemetrySDK(),
		// Add your own custom attributes to identify your application
		resource.WithAttributes(
			semconv.ServiceName(appName),
		),
	)
	if err != nil {
		log.Fatalf("resource.New: %v", err)
	}

	// Create trace provider with the exporter.
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.TraceIDRatioBased(sampleRate)),
	)

	otel.SetTracerProvider(tp)

	return func() {
		tp.ForceFlush(ctx)
		if err := tp.Shutdown(context.Background()); err != nil {
			log.Fatal(err)
		}
	}
}

func histogramBoundaries() []float64 {
	boundaries := make([]float64, 0)
	boundary := 0.0
	increment := 2.0
	for range 50 {
		boundaries = append(boundaries, boundary)
		boundary += increment
	}
	boundary = 100.0
	increment = 10.0
	for i := range 150 {
		if boundary >= 300_000 {
			break
		}
		boundaries = append(boundaries, boundary)
		if i != 0 && i%10 == 0 {
			increment *= 2
		}
		boundary += increment
	}
	return boundaries
}

func enableMeter(ctx context.Context, projectID string, instance string) func() {
	exporter, err := expmetric.New(
		expmetric.WithProjectID(projectID),
	)
	if err != nil {
		log.Fatalf("Cannot create exporter: %v", err)
	}

	// We want this metric to be about the `generic_task` monitored resource
	// type.  The monitoring resource type is assigned automatically by the
	// Cloud Monitoring exporter, based on what attributes are present. We
	// have to filter most of the GCP attributes or the exporter things the
	// metric is about the GCE instance.
	attributes := []attribute.KeyValue{
		semconv.ServiceName(appName),
		semconv.ServiceNamespace("default"),
		semconv.ServiceInstanceID(instance),
	}
	// We want the location field from GCP.
	if resource, err := gcp.NewDetector().Detect(ctx); err == nil {
		for _, attr := range resource.Attributes() {
			if attr.Key == semconv.CloudRegionKey {
				attributes = append(attributes, attr)
			} else if attr.Key == semconv.CloudAvailabilityZoneKey {
				attributes = append(attributes, attr)
			}
		}
	}
	res, err := resource.New(ctx,
		// Keep the default detectors. Do not use the GCP detector because that
		// makes the metric a "GCE instance" metric or something similar.
		resource.WithTelemetrySDK(),
		// Add your own custom attributes to identify your application
		resource.WithAttributes(attributes...),
	)
	if err != nil {
		log.Fatalf("resource.New: %v", err)
	}

	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(
			sdkmetric.NewPeriodicReader(
				exporter,
				sdkmetric.WithInterval(60*time.Second),
			)),
	)

	// Register as global meter provider so that it can be used via otel.Meter
	// and accessed using otel.GetMeterProvider.
	// Most instrumentation libraries use the global meter provider as default.
	// If the global meter provider is not set then a no-op implementation
	// is used, which fails to generate data.
	otel.SetMeterProvider(meterProvider)

	// Handle shutdown properly so nothing leaks.
	return func() {
		log.Print("Shutting down meter provider")
		if err := meterProvider.Shutdown(context.Background()); err != nil {
			log.Println(err)
		}
	}
}

func enableProfiler(projectID string, deployment string, profilerVersion string) func() {
	cfg := profiler.Config{
		Service:        fmt.Sprintf("w1r3.%s", deployment),
		ServiceVersion: profilerVersion,
		ProjectID:      projectID,
		MutexProfiling: true,
	}

	if err := profiler.Start(cfg); err != nil {
		log.Fatal(err)
	}
	return func() {}
}

func benchmarkVersion() string {
	buildInfo, ok := debug.ReadBuildInfo()
	version := ""
	modified := false
	if ok {
		for _, s := range buildInfo.Settings {
			if s.Key == "vcs.revision" {
				version = s.Value
			} else if s.Key == "vcs.modified" {
				modified = (s.Value == "true")
			}
		}
	}
	// On Google Cloud Build there is no VCS information if the build is
	// triggered manually.
	if version == "" {
		return "unknown"
	}
	// Use the short git version.
	if len(version) == 40 {
		version = version[0:7]
	}
	if modified {
		return version + ".dirty"
	}
	return version
}

// Accumulate multiple string flags into an array.
type stringFlags []string

func (i *stringFlags) String() string {
	return strings.Join(*i, ",")
}

func (i *stringFlags) Set(value string) error {
	*i = append(*i, value)
	return nil
}

// Accumulate multiple int flags into an array.
type intFlags []int64

func (i *intFlags) String() string {
	return fmt.Sprint(*i)
}

func (i *intFlags) Set(value string) error {
	v, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return err
	}
	*i = append(*i, v)
	return nil
}

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

import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import com.google.cloud.opentelemetry.trace.TraceConfiguration;
import com.google.cloud.opentelemetry.trace.TraceExporter;
import com.google.cloud.opentelemetry.metric.MetricConfiguration;
import com.google.cloud.opentelemetry.metric.MetricDescriptorStrategy;
import com.google.cloud.opentelemetry.metric.GoogleCloudMetricExporter;
import com.google.cloud.opentelemetry.detectors.GCPResource;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.metrics.SdkMeterProvider;
import io.opentelemetry.sdk.metrics.export.PeriodicMetricReader;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.samplers.Sampler;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.concurrent.Callable;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.Random;
import java.util.UUID;

@Command(name = "w1r3", mixinStandardHelpOptions = true, version = "", description = "Runs the w1r3 benchmark.")
final class W1R3 implements Callable<Integer> {
    private static final String serviceName = "w1r3";
    private static final String scopeName = "w1r3";
    private static final String scopeVersion = "0.0.1";
    private static final double sampleRate = 0.05;
    private final int KB = 1000;
    private final int KiB = 1024;
    private final int MB = 1000 * KB;
    private final int MiB = 1024 * KiB;

    @Option(names = "-project-id", description = "the Google Cloud Platform project ID used by the benchmark", required = true)
    private String project;

    @Option(names = "-bucket", description = "the bucket used by the benchmark", required = true)
    private String bucket;

    @Option(names = "-deployment", description = "where is the benchmark runing. For example: development, MIG, GKE, GCE.", defaultValue = "development")
    private String deployment;

    @Option(names = "-iterations", description = "how many iterations to run.", defaultValue = "1000000")
    private int iterations;

    @Option(names = "-workers", description = "the number of concurrent threads running the benchmark", defaultValue = "1")
    private int workers;

    @Option(names = "-transport", description = "the transports (JSON, GRPC+CFE, GRPC+DP) used by the benchmark")
    private String[] transports;

    @Option(names = "-object-size", description = "the object sizes used by the benchmark")
    private Integer[] objectSizes;

    public static void main(String... args) {
        var exitCode = new CommandLine(new W1R3()).execute(args);
        System.exit(exitCode);
    }

    @Override
    public Integer call() throws Exception {
        if (transports == null || transports.length == 0) {
            transports = new String[] { "JSON", "GRPC+CFE", "GRPC+DP" };
        }
        if (objectSizes == null || objectSizes.length == 0) {
            objectSizes = new Integer[] { 100 * KB, 2 * MiB, 100 * MB };
        }
        var instance = UUID.randomUUID().toString();

        System.out.printf("## Starting continuous GCS Java SDK benchmark\n");
        System.out.printf("# object-sizes: %s\n", Arrays.toString(this.objectSizes));
        System.out.printf("# transports: %s\n", Arrays.toString(this.transports));
        System.out.printf("# project-id: %s\n", this.project);
        System.out.printf("# bucket: %s\n", this.bucket);
        System.out.printf("# deployment: %s\n", this.deployment);
        System.out.printf("# instance: %s\n", instance);
        System.out.printf("# Java SDK Version %s\n", sdkVersion);
        System.out.printf("# HTTP Version %s\n", httpClientVersion);
        System.out.printf("# Protobuf Version %s\n", protobufVersion);
        System.out.printf("# gRPC Version %s\n", grpcVersion);

        var random = new SecureRandom();
        var randomData = makeRandomData(this.objectSizes, random);

        var otelSdk = setupOpenTelemetrySdk(instance);

        var clients = makeClients(transports);
        var uploaders = makeUploaders();
        var workers = new ArrayList<Thread>();
        for (int i = 0; i != this.workers; ++i) {
            workers.add(new Thread(
                    (() -> {
                        worker(clients, uploaders, randomData, random.nextInt(), instance, otelSdk);
                    })));
        }
        for (var t : workers)
            t.start();
        for (var t : workers)
            t.join();
        return 0;
    }

    public static class Transport {
        public Transport(String n, Storage c) {
            name = n;
            client = c;
        }

        public final String name;
        public final Storage client;
    }

    public static interface Uploader {
        public BlobId upload(Storage client, BlobInfo info, ByteBuffer input) throws Exception;

        public String name();
    }

    private void worker(
            Transport[] transports, Uploader[] uploaders,
            byte[] randomData, int seed, String instance,
            OpenTelemetrySdk otelSdk) {
        var random = new Random(seed);
        var tracer = otelSdk.getTracer(scopeName, scopeVersion);
        var meter = otelSdk.getMeter(scopeName);
        var histogram = meter.histogramBuilder("ssb/w1r3/latency")
                .setExplicitBucketBoundariesAdvice(makeLatencyBoundaries())
                .setUnit("s").build();
        for (long i = 0; i != this.iterations; ++i) {
            var transport = pickOne(transports, random);
            var uploader = pickOne(uploaders, random);
            var client = transport.client;
            var objectSize = pickOne(this.objectSizes, random);
            var objectName = UUID.randomUUID().toString();
            var blobInfo = BlobInfo.newBuilder(BlobId.of(this.bucket, objectName)).build();

            var tracingAttributes = Attributes.builder()
                    .put("ssb.language", "java")
                    .put("ssb.object-size", objectSize)
                    .put("ssb.transport", transport.name)
                    .put("ssb.deployment", deployment)
                    .put("ssb.instance", instance)
                    .put("ssb.version", "unknown")
                    .put("ssb.version.sdk", sdkVersion)
                    .put("ssb.version.grpc", grpcVersion)
                    .put("ssb.version.protobuf", protobufVersion)
                    .put("ssb.version.http-client", httpClientVersion)
                    .build();

            var meterAttributes = Attributes.builder()
                    .put("ssb_language", "java")
                    .put("ssb_object_size", objectSize)
                    .put("ssb_transport", transport.name)
                    .put("ssb_deployment", deployment)
                    .put("ssb_instance", instance)
                    .put("ssb_version", "unknown")
                    .put("ssb_version_sdk", sdkVersion)
                    .put("ssb_version_grpc", grpcVersion)
                    .put("ssb_version_protobuf", protobufVersion)
                    .put("ssb_version_http_client", httpClientVersion)
                    .build();

            var iterationSpan = tracer.spanBuilder("ssb::iteration")
                .setAllAttributes(tracingAttributes)
                .setAttribute("ssb.iteration", i)
                .startSpan();

            double nanosPerSecond = Duration.ofSeconds(1).toNanos();

            try (var iterationScope = iterationSpan.makeCurrent()) {
                var uploadSpan = tracer.spanBuilder("ssb::upload")
                        .setAllAttributes(tracingAttributes)
                        .setAttribute("ssb.op", uploader.name()).startSpan();
                BlobId blobId = null;
                try (var uploadScope = uploadSpan.makeCurrent()) {
                    var start = System.nanoTime();
                    blobId = uploader.upload(
                        client, blobInfo,
                        ByteBuffer.wrap(randomData, 0, objectSize));
                    var elapsed = System.nanoTime() - start;
                    histogram.record(elapsed / nanosPerSecond,
                            Attributes.builder()
                            .putAll(meterAttributes)
                            .put("ssb_op", uploader.name()).build());
                } catch (Exception e) {
                    uploadSpan.recordException(e);
                    continue;
                } finally {
                    uploadSpan.end();
                }

                for (int r = 0; r != 3; ++r) {
                    var opName = "READ[" + String.valueOf(r) + "]";
                    var downloadSpan = tracer.spanBuilder("ssb::download")
                        .setAllAttributes(tracingAttributes)
                        .setAttribute("ssb.op", opName).startSpan();
                    try (var downloadScope = downloadSpan.makeCurrent()) {
                        var start = System.nanoTime();
                        var reader = client.reader(blobId);
                        while (reader.isOpen()) {
                            var discard = ByteBuffer.allocate(2 * MiB);
                            if (reader.read(discard) == -1) {
                                break;
                            }
                        }
                        reader.close();
                        var elapsed = System.nanoTime() - start;
                        histogram.record(elapsed / nanosPerSecond,
                                Attributes.builder()
                                .putAll(meterAttributes)
                                .put("ssb_op", opName).build());
                    } catch (Exception e) {
                        downloadSpan.recordException(e);
                    } finally {
                        downloadSpan.end();
                    }
                }

                client.delete(blobId);
            } finally {
                iterationSpan.end();
            }
        }
    }

    private static <T> T pickOne(T[] elements, Random random) {
        return elements[random.nextInt(elements.length)];
    }

    private static Transport[] makeClients(String[] names) throws Exception {
        var transports = new ArrayList<Transport>();
        for (var t : names) {
            if (t.equals("JSON")) {
                transports.add(new Transport(t, StorageOptions.getDefaultInstance().getService()));
            } else if (t.equals("GRPC+CFE")) {
                transports.add(new Transport(t, StorageOptions.grpc().build().getService()));
            } else if (t.equals("GRPC+DP")) {
                transports.add(new Transport(t, StorageOptions.grpc().setAttemptDirectPath(true).build().getService()));
            } else {
                throw new Exception("Unknown transport <" + t + ">");
            }
        }
        var result = new Transport[transports.size()];
        transports.toArray(result);
        return result;
    }

    private static class SingleShotUploader implements Uploader {
        public BlobId upload(Storage client, BlobInfo blob, ByteBuffer input) throws Exception {
            var length = input.limit() - input.arrayOffset();
            return client.create(blob, input.array(), input.arrayOffset(), length).asBlobInfo().getBlobId();
        }

        public String name() {
            return "SINGLE-SHOT";
        }
    }

    private static class ResumableUploader implements Uploader {
        public BlobId upload(Storage client, BlobInfo blob, ByteBuffer input) throws Exception {
            var writer = client.writer(blob);
            writer.write(input);
            writer.close();
            return blob.getBlobId();
        }

        public String name() {
            return "RESUMABLE";
        }
    }

    private static Uploader[] makeUploaders() {
        return new Uploader[] { new SingleShotUploader(), new ResumableUploader() };
    }

    private static byte[] makeRandomData(Integer[] objectSizes, Random random) throws Exception {
        Integer size = 0;
        for (var s : objectSizes) {
            size = size < s ? s : size;
        }
        var buffer = new byte[size];
        random.nextBytes(buffer);
        return buffer;
    }

    private OpenTelemetrySdk setupOpenTelemetrySdk(String instance) {
        var meterResourceBuilder = Attributes.builder()
                        .put("service.namespace", "default")
                        .put("service.name", serviceName)
                        .put("service.instance.id", instance);
        var gcpResource = new GCPResource();
        gcpResource.getAttributes().forEach((attributeKey, value) -> {
            var key = attributeKey.getKey();
            if (key.equals("cloud.region")) {
                meterResourceBuilder.put(key, (String)value);
            } else if (key.equals("cloud.availability_zone")) {
                meterResourceBuilder.put(key, (String)value);
            }
        });

        var meterResource = Resource.getDefault()
                .merge(Resource.create(meterResourceBuilder.build()));

        var metricConfiguration = MetricConfiguration.builder().setProjectId(project)
                .setDeadline(Duration.ofSeconds(30))
                .setDescriptorStrategy(MetricDescriptorStrategy.NEVER_SEND)
                .build();
        var metricExporter = GoogleCloudMetricExporter.createWithConfiguration(metricConfiguration);
        var meterProvider = SdkMeterProvider.builder().setResource(meterResource)
                .registerMetricReader(
                        PeriodicMetricReader.builder(metricExporter)
                                .setInterval(Duration.ofSeconds(60)).build())
                .build();

        var traceConfiguration = TraceConfiguration.builder()
                .setProjectId(project)
                .setDeadline(Duration.ofSeconds(30)).build();
        var traceExporter = TraceExporter.createWithConfiguration(traceConfiguration);

        var traceProvider = SdkTracerProvider.builder()
                .setResource(Resource.getDefault().merge(Resource.create(gcpResource.getAttributes())))
                .setSampler(Sampler.traceIdRatioBased(sampleRate))
                .addSpanProcessor(BatchSpanProcessor.builder(traceExporter)
                        .setMeterProvider(meterProvider).build())
                .build();

        // Register the exporters with OpenTelemetry
        return OpenTelemetrySdk.builder()
                .setTracerProvider(traceProvider)
                .setMeterProvider(meterProvider)
                .buildAndRegisterGlobal();
    }

	// We want millisecond-sized histogram buckets. Floating point arithmetic is
	// famously tricky, and time arithmetic is also error prone. Avoid most of
	// these problems by using `Duration` to do all the arithmetic, and only
    // convert to `double` (and seconds) when needed.
    private static List<Double> makeLatencyBoundaries() {
        var boundaries = new ArrayList<Double>();
        var boundary = Duration.ofSeconds(0);
        var increment = Duration.ofMillis(2);
        for (int i = 0; i != 50; ++i) {
            boundaries.add(boundary.toMillis() / 1000.0);
            boundary = boundary.plus(increment);
        }
        boundary = Duration.ofMillis(100);
        increment = Duration.ofMillis(10);
        for (int i = 0; i != 150; ++i) {
            if (boundary.compareTo(Duration.ofSeconds(300)) >= 0)
                break;
            boundaries.add(boundary.toMillis() / 1000.0);
            if (i != 0 && i % 10 == 0)
                increment = increment.multipliedBy(2);
            boundary = boundary.plus(increment);
        }
        return boundaries;
    }

    private static String getPackageVersion(String groupId, String artifactId) {
        var path = String.format("/META-INF/maven/%s/%s/pom.properties", groupId, artifactId);
        try {
            var props = new Properties();
            var stream = W1R3.class.getResourceAsStream(path);
            if (stream != null) {
                props.load(stream);
                stream.close();
                return props.getProperty("version");
            }
        } catch (IOException e) {
        }
        return "unknown";
    }

    private static final String sdkVersion = getPackageVersion("com.google.cloud", "google-cloud-storage");
    private static final String httpClientVersion = getPackageVersion("com.google.http-client", "google-http-client");
    private static final String protobufVersion = getPackageVersion("com.google.protobuf", "protobuf-java");
    private static final String grpcVersion = getPackageVersion("io.grpc", "grpc-core");
};

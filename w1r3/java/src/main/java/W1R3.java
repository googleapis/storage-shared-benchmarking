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

import com.google.cloud.opentelemetry.detectors.GCPResource;
import com.google.cloud.opentelemetry.metric.GoogleCloudMetricExporter;
import com.google.cloud.opentelemetry.metric.MetricConfiguration;
import com.google.cloud.opentelemetry.metric.MetricDescriptorStrategy;
import com.google.cloud.opentelemetry.trace.TraceConfiguration;
import com.google.cloud.opentelemetry.trace.TraceExporter;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.Storage.BlobTargetOption;
import com.google.cloud.storage.StorageOptions;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.metrics.SdkMeterProvider;
import io.opentelemetry.sdk.metrics.export.PeriodicMetricReader;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.sdk.trace.samplers.Sampler;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Properties;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.Callable;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import runtime.Instrumentation;

@Command(
    name = "w1r3",
    mixinStandardHelpOptions = true,
    version = "",
    description = "Runs the w1r3 benchmark.")
final class W1R3 implements Callable<Integer> {
  private static final String SERVICE_NAME = "w1r3";
  private static final String SCOPE_NAME = "w1r3";
  private static final String SCOPE_VERSION = "0.0.1";
  private static final double DEFAULT_SAMPLE_RATE = 0.05;
  private static final int KB = 1000;
  private static final int KiB = 1024;
  private static final int MB = 1000 * KB;
  private static final int MiB = 1024 * KiB;

  private static final String SDK_VERSION =
      getPackageVersion("com.google.cloud", "google-cloud-storage");
  private static final String HTTP_CLIENT_VERSION =
      getPackageVersion("com.google.http-client", "google-http-client");
  private static final String PROTOBUF_VERSION =
      getPackageVersion("com.google.protobuf", "protobuf-java");
  private static final String GRPC_VERSION = getPackageVersion("io.grpc", "grpc-core");

  @Option(
      names = "-project-id",
      description = "the Google Cloud Platform project ID used by the benchmark",
      required = true)
  private String project;

  @Option(names = "-bucket", description = "the bucket used by the benchmark", required = true)
  private String bucket;

  @Option(
      names = "-deployment",
      description = "where is the benchmark runing. For example: development, MIG, GKE, GCE.",
      defaultValue = "development")
  private String deployment;

  @Option(
      names = "-iterations",
      description = "how many iterations to run.",
      defaultValue = "1000000")
  private int iterations;

  @Option(
      names = "-workers",
      description = "the number of concurrent threads running the benchmark",
      defaultValue = "1")
  private int workers;

  @Option(
      names = "-transport",
      description = "the transports (JSON, GRPC+CFE, GRPC+DP) used by the benchmark")
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
      transports = new String[] {"JSON", "GRPC+CFE", "GRPC+DP"};
    }
    if (objectSizes == null || objectSizes.length == 0) {
      objectSizes = new Integer[] {100 * KB, 2 * MiB, 100 * MB};
    }
    var instance = UUID.randomUUID().toString();

    System.out.printf("## Starting continuous GCS Java SDK benchmark%n");
    System.out.printf("# object-sizes: %s%n", Arrays.toString(this.objectSizes));
    System.out.printf("# transports: %s%n", Arrays.toString(this.transports));
    System.out.printf("# project-id: %s%n", this.project);
    System.out.printf("# bucket: %s%n", this.bucket);
    System.out.printf("# deployment: %s%n", this.deployment);
    System.out.printf("# instance: %s%n", instance);
    System.out.printf("# Java SDK Version %s%n", SDK_VERSION);
    System.out.printf("# HTTP Version %s%n", HTTP_CLIENT_VERSION);
    System.out.printf("# Protobuf Version %s%n", PROTOBUF_VERSION);
    System.out.printf("# gRPC Version %s%n", GRPC_VERSION);

    var random = new SecureRandom();
    var randomData = makeRandomData(this.objectSizes, random);

    try (var otelSdk = setupOpenTelemetrySdk(instance)) {
      var clients = makeClients(transports);
      var uploaders = makeUploaders();
      var workers = new ArrayList<Thread>();
      for (int i = 0; i != this.workers; ++i) {
        workers.add(
            new Thread(
                (() -> {
                  worker(clients, uploaders, randomData, random.nextInt(), instance, otelSdk);
                })));
      }
      for (var t : workers) t.start();
      for (var t : workers) t.join();
    }
    return 0;
  }

  public static class Transport {
    public final String name;
    public final Storage client;

    public Transport(String n, Storage c) {
      name = n;
      client = c;
    }
  }

  public interface Uploader {
    BlobId upload(Storage client, BlobInfo info, ByteBuffer input) throws Exception;

    String name();
  }

  private void worker(
      Transport[] transports,
      Uploader[] uploaders,
      byte[] randomData,
      int seed,
      String instance,
      OpenTelemetrySdk otelSdk) {
    var random = new Random(seed);
    var tracer = otelSdk.getTracer(SCOPE_NAME, SCOPE_VERSION);
    var meter = otelSdk.getMeter(SCOPE_NAME);
    var latencyHistogram =
        meter
            .histogramBuilder("ssb/w1r3/latency")
            .setExplicitBucketBoundariesAdvice(makeLatencyBoundaries())
            .setUnit("s")
            .build();

    var cpuPerByteHistogram =
        meter
            .histogramBuilder("ssb/w1r3/cpu")
            .setExplicitBucketBoundariesAdvice(makeCpuBoundaries())
            .setUnit("ns/By{CPU}")
            .build();

    var allocatedBytesPerByteHistogram =
        meter
            .histogramBuilder("ssb/w1r3/memory")
            .setExplicitBucketBoundariesAdvice(makeMemoryHistogramBoundaries())
            .setUnit("1{memory}")
            .build();

    Instrumentation instrumentation =
        new Instrumentation(latencyHistogram, cpuPerByteHistogram, allocatedBytesPerByteHistogram);
    // pre-allocate the buffer we will use for reads
    var readBuffer = ByteBuffer.allocate(2 * MiB);
    for (long i = 0; i != this.iterations; ++i) {
      var transport = pickOne(transports, random);
      var uploader = pickOne(uploaders, random);
      var client = transport.client;
      var objectSize = pickOne(this.objectSizes, random);
      var objectName = UUID.randomUUID().toString();
      var blobInfo = BlobInfo.newBuilder(BlobId.of(this.bucket, objectName)).build();

      var tracingAttributes =
          Attributes.builder()
              .put("ssb.language", "java")
              .put("ssb.object-size", objectSize)
              .put("ssb.transport", transport.name)
              .put("ssb.deployment", deployment)
              .put("ssb.instance", instance)
              .put("ssb.version", "unknown")
              .put("ssb.version.sdk", SDK_VERSION)
              .put("ssb.version.grpc", GRPC_VERSION)
              .put("ssb.version.protobuf", PROTOBUF_VERSION)
              .put("ssb.version.http-client", HTTP_CLIENT_VERSION)
              .build();

      var meterAttributes =
          Attributes.builder()
              .put("ssb_language", "java")
              .put("ssb_object_size", objectSize)
              .put("ssb_transport", transport.name)
              .put("ssb_deployment", deployment)
              .put("ssb_instance", instance)
              .put("ssb_version", "unknown")
              .put("ssb_version_sdk", SDK_VERSION)
              .put("ssb_version_grpc", GRPC_VERSION)
              .put("ssb_version_protobuf", PROTOBUF_VERSION)
              .put("ssb_version_http_client", HTTP_CLIENT_VERSION)
              .build();

      var iterationSpan =
          tracer
              .spanBuilder("ssb::iteration")
              .setAllAttributes(tracingAttributes)
              .setAttribute("ssb.iteration", i)
              .startSpan();

      try (var iterationScope = iterationSpan.makeCurrent()) {
        var uploadSpan =
            tracer
                .spanBuilder("ssb::upload")
                .setAllAttributes(tracingAttributes)
                .setAttribute("ssb.op", uploader.name())
                .startSpan();
        BlobId blobId = null;
        var uploadAttributes =
            Attributes.builder().putAll(meterAttributes).put("ssb_op", uploader.name()).build();
        try (var uploadScope = uploadSpan.makeCurrent()) {
          var measurement = instrumentation.measure(objectSize, uploadAttributes);
          blobId = uploader.upload(client, blobInfo, ByteBuffer.wrap(randomData, 0, objectSize));
          measurement.report();
        } catch (Exception e) {
          uploadSpan.recordException(e);
          continue;
        } finally {
          uploadSpan.end();
        }

        for (int r = 0; r != 3; ++r) {
          var opName = String.format("READ[%d]", r);
          var downloadSpan =
              tracer
                  .spanBuilder("ssb::download")
                  .setAllAttributes(tracingAttributes)
                  .setAttribute("ssb.op", opName)
                  .startSpan();
          var downloadAttributes =
              Attributes.builder().putAll(meterAttributes).put("ssb_op", opName).build();
          readBuffer.clear();
          try (var downloadScope = downloadSpan.makeCurrent()) {
            var measurement = instrumentation.measure(objectSize, downloadAttributes);
            var reader = client.reader(blobId);
            while (reader.isOpen()) {
              if (reader.read(readBuffer) == -1) {
                break;
              }
            }
            reader.close();
            measurement.report();
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
        transports.add(
            new Transport(
                t, StorageOptions.grpc().setAttemptDirectPath(true).build().getService()));
      } else {
        throw new Exception("Unknown transport <" + t + ">");
      }
    }
    var result = new Transport[transports.size()];
    transports.toArray(result);
    return result;
  }

  private static class SingleShotUploader implements Uploader {
    private static final BlobTargetOption[] BLOB_TARGET_OPTIONS =
        new BlobTargetOption[] {
          // disable gzip content so HTTP client doesn't try to compress a 100MiB random payload
          BlobTargetOption.disableGzipContent()
        };

    public BlobId upload(Storage client, BlobInfo blob, ByteBuffer input) throws Exception {
      var length = input.limit() - input.arrayOffset();
      return client
          .create(blob, input.array(), input.arrayOffset(), length, BLOB_TARGET_OPTIONS)
          .getBlobId();
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
    return new Uploader[] {new SingleShotUploader(), new ResumableUploader()};
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
    var meterResourceBuilder =
        Attributes.builder()
            .put("service.namespace", "default")
            .put("service.name", SERVICE_NAME)
            .put("service.instance.id", instance);
    var gcpResource = new GCPResource();
    gcpResource
        .getAttributes()
        .forEach(
            (attributeKey, value) -> {
              var key = attributeKey.getKey();
              if (key.equals("cloud.region")) {
                meterResourceBuilder.put(key, (String) value);
              } else if (key.equals("cloud.availability_zone")) {
                meterResourceBuilder.put(key, (String) value);
              }
            });

    var meterResource = Resource.getDefault().merge(Resource.create(meterResourceBuilder.build()));

    var metricConfiguration =
        MetricConfiguration.builder()
            .setProjectId(project)
            .setDeadline(Duration.ofSeconds(30))
            .setDescriptorStrategy(MetricDescriptorStrategy.NEVER_SEND)
            .build();
    var metricExporter = GoogleCloudMetricExporter.createWithConfiguration(metricConfiguration);
    var meterProvider =
        SdkMeterProvider.builder()
            .setResource(meterResource)
            .registerMetricReader(
                PeriodicMetricReader.builder(metricExporter)
                    .setInterval(Duration.ofSeconds(60))
                    .build())
            .build();

    var traceConfiguration =
        TraceConfiguration.builder()
            .setProjectId(project)
            .setDeadline(Duration.ofSeconds(30))
            .build();
    var traceExporter = TraceExporter.createWithConfiguration(traceConfiguration);

    var traceProvider =
        SdkTracerProvider.builder()
            .setResource(Resource.getDefault().merge(Resource.create(gcpResource.getAttributes())))
            .setSampler(Sampler.traceIdRatioBased(DEFAULT_SAMPLE_RATE))
            .addSpanProcessor(
                BatchSpanProcessor.builder(traceExporter).setMeterProvider(meterProvider).build())
            .build();

    // Register the exporters with OpenTelemetry
    return OpenTelemetrySdk.builder()
        .setTracerProvider(traceProvider)
        .setMeterProvider(meterProvider)
        .buildAndRegisterGlobal();
  }

  // We want millisecond-sized histogram buckets expressed in seconds.
  // Floating point arithmetic is famously tricky, and time arithmetic is also
  // error prone. Avoid most of these problems by using `Duration` to do all
  // the arithmetic, and only
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
      if (boundary.compareTo(Duration.ofSeconds(300)) >= 0) break;
      boundaries.add(boundary.toMillis() / 1000.0);
      if (i != 0 && i % 10 == 0) increment = increment.multipliedBy(2);
      boundary = boundary.plus(increment);
    }
    return boundaries;
  }

  private static List<Double> makeCpuBoundaries() {
    int numBuckets = 200;
    ArrayList<Double> boundaries = new ArrayList<>(numBuckets);
    double boundary = 0.0;
    double increment = 0.1;
    for (int i = 0; i < numBuckets; i++) {
      boundaries.add(boundary);
      if (i != 0 && i % 100 == 0) {
        increment *= 2;
      }
      boundary += increment;
    }
    return boundaries;
  }

  /**
   * Cloud Monitoring only supports up to 200 buckets per histogram. Use exponentially growing
   * bucket sizes
   */
  private static List<Double> makeMemoryHistogramBoundaries() {
    int numBuckets = 200;
    ArrayList<Double> boundaries = new ArrayList<>(numBuckets);
    double boundary = 0.0;
    double increment = 1.0 / 16.0;
    for (int i = 0; i < numBuckets; i++) {
      boundaries.add(boundary);
      if (i != 0 && i % 16 == 0) {
        increment *= 2;
      }
      boundary += increment;
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
}

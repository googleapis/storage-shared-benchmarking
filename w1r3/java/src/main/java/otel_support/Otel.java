/*
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package otel_support;

import static com.google.common.base.Preconditions.checkState;

import com.google.cloud.opentelemetry.detectors.GCPResource;
import com.google.cloud.opentelemetry.metric.GoogleCloudMetricExporter;
import com.google.cloud.opentelemetry.metric.MetricConfiguration;
import com.google.cloud.opentelemetry.metric.MetricDescriptorStrategy;
import com.google.cloud.opentelemetry.trace.TraceConfiguration;
import com.google.cloud.opentelemetry.trace.TraceExporter;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.common.AttributesBuilder;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.metrics.SdkMeterProvider;
import io.opentelemetry.sdk.metrics.export.PeriodicMetricReader;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.sdk.trace.samplers.Sampler;
import java.time.Duration;

public final class Otel implements AutoCloseable {

  private static final double DEFAULT_SAMPLE_RATE = 0.05;
  private final OpenTelemetrySdk openTelemetrySdk;
  private final Attributes baseMeterAttributes;
  private final Attributes baseTracingAttributes;
  private final Tracer baseTracer;
  private final Meter baseMeter;
  private final String region;

  private Otel(
      OpenTelemetrySdk openTelemetrySdk,
      Attributes baseMeterAttributes,
      Attributes baseTracingAttributes,
      Tracer baseTracer,
      Meter baseMeter,
      String region) {
    this.openTelemetrySdk = openTelemetrySdk;
    this.baseMeterAttributes = baseMeterAttributes;
    this.baseTracingAttributes = baseTracingAttributes;
    this.baseTracer = baseTracer;
    this.baseMeter = baseMeter;
    this.region = region;
  }

  public String getRegion() {
    return region;
  }

  public Tracer getBaseTracer() {
    return baseTracer;
  }

  public Meter getBaseMeter() {
    return baseMeter;
  }

  public AttributesBuilder newMeterAttributesBuilder() {
    return Attributes.builder().putAll(baseMeterAttributes);
  }

  public AttributesBuilder newTracingAttributesBuilder() {
    return Attributes.builder().putAll(baseTracingAttributes);
  }

  @Override
  public void close() {
    openTelemetrySdk.close();
  }

  public static Otel create(
      String serviceName,
      String project,
      String instance,
      Attributes baseTracingAttributes,
      String baseScopeName,
      String baseScopeVersion) {
    OpenTelemetrySdk sdk = setupOpenTelemetrySdk(serviceName, project, instance);
    var tracer = sdk.getTracer(baseScopeName, baseScopeVersion);
    var meter = sdk.getMeter(baseScopeName);
    AttributesBuilder baseMeterAttributesBuilder = Attributes.builder();
    baseTracingAttributes.forEach(
        (key, value) -> {
          String newKey = key.getKey().replaceAll("[.-]", "_");
          // AttributeBuilder#put doesn't accept Object. Only String, int, long, double or boolean
          // today we are only attaching string attributes
          checkState(value instanceof String, "Unhandled attribute type %s", value.getClass());
          baseMeterAttributesBuilder.put(newKey, (String) value);
        });
    Attributes baseMeterAttributes = baseMeterAttributesBuilder.build();
    String region = discoverRegion();
    return new Otel(sdk, baseMeterAttributes, baseTracingAttributes, tracer, meter, region);
  }

  public static String discoverRegion() {
    var region = new StringBuilder();
    var gcpResource = new GCPResource();
    gcpResource
        .getAttributes()
        .forEach(
            (attributeKey, value) -> {
              var key = attributeKey.getKey();
              if (key.equals("cloud.region")) {
                region.append((String) value);
              }
            });
    var r = region.toString();
    if (r.isEmpty()) return "unknown";
    return r;
  }

  private static OpenTelemetrySdk setupOpenTelemetrySdk(
      String serviceName, String project, String instance) {
    var meterResourceBuilder =
        Attributes.builder()
            .put("service.namespace", "default")
            .put("service.name", serviceName)
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
}

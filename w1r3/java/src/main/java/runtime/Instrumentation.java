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

package runtime;

import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.DoubleHistogram;
import java.time.Duration;

public final class Instrumentation {

  private static final double NANOS_PER_SECOND = Duration.ofSeconds(1).toNanos();

  private final DoubleHistogram latencyHistogram;
  private final DoubleHistogram cpuPerByteHistogram;

  public Instrumentation(DoubleHistogram latencyHistogram, DoubleHistogram cpuPerByteHistogram) {
    this.latencyHistogram = latencyHistogram;
    this.cpuPerByteHistogram = cpuPerByteHistogram;
  }

  public Measurement measure(long objectSize, Attributes attributes) {
    return new Measurement(objectSize, attributes);
  }

  // when measuring we want to by symmetric in our evaluation of measurements.
  // latency is the closest to the operation, with cpuNs next closest. In the beginning measurements
  // this means the latency will happen last, whereas on the report side of things latency will be
  // first.
  public final class Measurement {

    private final long objectSize;
    private final Attributes attributes;

    private final long beginNs;
    private final long beginCpuNs;

    public Measurement(long objectSize, Attributes attributes) {
      this.objectSize = objectSize;
      this.attributes = attributes;
      this.beginCpuNs = CpuTime.getTotalCpuNanos();
      this.beginNs = System.nanoTime();
    }

    public void report() {
      long endNs = System.nanoTime();
      long endCpuNs = CpuTime.getTotalCpuNanos();

      long elapsed = endNs - beginNs;
      long diffCpuNs = endCpuNs - beginCpuNs;

      double latencyS = elapsed / NANOS_PER_SECOND;
      double cpuPerByte = objectSize / ((double) diffCpuNs);

      latencyHistogram.record(latencyS, attributes);
      cpuPerByteHistogram.record(cpuPerByte, attributes);
    }
  }
}

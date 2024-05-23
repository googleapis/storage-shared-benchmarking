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

import com.google.cloud.Tuple;
import com.google.common.collect.Streams;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.DoubleHistogram;
import java.io.IOException;
import java.lang.management.MemoryType;
import java.time.Duration;
import java.util.List;
import java.util.stream.Collectors;
import runtime.GcEvent.GcEventDiff;

public final class Instrumentation {

  private static final double NANOS_PER_SECOND = Duration.ofSeconds(1).toNanos();

  private final DoubleHistogram latencyHistogram;
  private final DoubleHistogram cpuPerByteHistogram;
  private final DoubleHistogram allocatedBytesPerByteHistogram;

  public Instrumentation(
      DoubleHistogram latencyHistogram,
      DoubleHistogram cpuPerByteHistogram,
      DoubleHistogram allocatedBytesPerByteHistogram) {
    this.latencyHistogram = latencyHistogram;
    this.cpuPerByteHistogram = cpuPerByteHistogram;
    this.allocatedBytesPerByteHistogram = allocatedBytesPerByteHistogram;
  }

  public Measurement measure(long objectSize, Attributes attributes)
      throws IOException, InterruptedException {
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
    private final GcEvent beginGcEvent;
    private final List<MemoryPoolUsage> beginMemoryPoolUsages;
    private final SetSize beginRss;

    public Measurement(long objectSize, Attributes attributes)
        throws IOException, InterruptedException {
      this.objectSize = objectSize;
      this.attributes = attributes;
      this.beginRss = SmapsRollup.get();
      this.beginMemoryPoolUsages = MemoryPools.getUsage();
      this.beginGcEvent = GcMonitor.awaitGc();
      this.beginCpuNs = CpuTime.getTotalCpuNanos();
      this.beginNs = System.nanoTime();
    }

    public void report() throws IOException, InterruptedException {
      // read all of our instruments
      long endNs = System.nanoTime();
      long endCpuNs = CpuTime.getTotalCpuNanos();
      GcEvent endGcEvent = GcMonitor.awaitGc();
      List<MemoryPoolUsage> endMemoryPoolUsages = MemoryPools.getUsage();
      SetSize endRss = SmapsRollup.get();

      // calculate differences from begin
      long elapsed = endNs - beginNs;
      long diffCpuNs = endCpuNs - beginCpuNs;

      SetSize deltaSetSize = endRss.sub(beginRss);
      GcEventDiff gcEventDiff = endGcEvent.sub(beginGcEvent);
      //noinspection UnstableApiUsage
      List<MemoryPoolUsage> pools =
          Streams.zip(endMemoryPoolUsages.stream(), beginMemoryPoolUsages.stream(), Tuple::of)
              .map(t -> t.x().sub(t.y()))
              .collect(Collectors.toList());

      long heapUsed =
          gcEventDiff.getPools().stream()
              .mapToLong(MemoryPoolUsage::getUsed)
              .filter(l -> l > 0)
              .sum();
      long nonHeapUsed =
          pools.stream()
              .filter(mpu -> mpu.getType() == MemoryType.NON_HEAP)
              .mapToLong(MemoryPoolUsage::getUsed)
              .filter(l -> l > 0)
              .sum();
      long bytesAllocated = Math.max(0L, heapUsed + (deltaSetSize.getRss()) - nonHeapUsed);

      double latencyS = elapsed / NANOS_PER_SECOND;
      double cpuPerByte = ((double) diffCpuNs) / objectSize;
      double allocatedBytesPerByte = ((double) bytesAllocated) / objectSize;

      latencyHistogram.record(latencyS, attributes);
      cpuPerByteHistogram.record(cpuPerByte, attributes);
      allocatedBytesPerByteHistogram.record(allocatedBytesPerByte, attributes);
    }
  }
}

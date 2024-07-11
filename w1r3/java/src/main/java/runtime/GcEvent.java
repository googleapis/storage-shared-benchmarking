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
import java.util.List;
import java.util.stream.Collectors;
import org.checkerframework.checker.nullness.qual.Nullable;

public final class GcEvent {

  private final long timestampNs;
  private final long count;
  private final List<MemoryPoolUsage> pre;
  private final List<MemoryPoolUsage> post;

  private GcEvent(
      long timestampNs, long count, List<MemoryPoolUsage> pre, List<MemoryPoolUsage> post) {
    this.timestampNs = timestampNs;
    this.count = count;
    this.pre = pre;
    this.post = post;
  }

  public long getTimestampNs() {
    return timestampNs;
  }

  /** Number of GC events since the start of the JVM */
  public long getCount() {
    return count;
  }

  /** Per pool usage breakdown before gc is performed */
  public List<MemoryPoolUsage> getPre() {
    return pre;
  }

  /** Per pool usage breakdown after gc was performed */
  public List<MemoryPoolUsage> getPost() {
    return post;
  }

  public GcEventDiff sub(@Nullable GcEvent other) {
    if (other == null) {
      return GcEventDiff.of(timestampNs, count, post);
    }
    //noinspection UnstableApiUsage
    return GcEventDiff.of(
        this.timestampNs - other.timestampNs,
        this.count - other.count,
        Streams.zip(this.pre.stream(), other.post.stream(), Tuple::of)
            .map(t -> t.x().sub(t.y()))
            .collect(Collectors.toList()));
  }

  public static GcEvent of(
      long timestampNs, long gcCount, List<MemoryPoolUsage> pre, List<MemoryPoolUsage> post) {
    return new GcEvent(timestampNs, gcCount, pre, post);
  }

  public static final class GcEventDiff {
    private final long durationNs;
    private final long count;
    private final List<MemoryPoolUsage> pools;

    private GcEventDiff(long durationNs, long count, List<MemoryPoolUsage> pools) {
      this.durationNs = durationNs;
      this.count = count;
      this.pools = pools;
    }

    public long getDurationNs() {
      return durationNs;
    }

    public long getCount() {
      return count;
    }

    public List<MemoryPoolUsage> getPools() {
      return pools;
    }

    @Override
    public String toString() {
      return String.format("%s{count=%d, pools=%s}", this.getClass().getSimpleName(), count, pools);
    }

    public static GcEventDiff of(long durationNs, long count, List<MemoryPoolUsage> diffs) {
      return new GcEventDiff(durationNs, count, diffs);
    }
  }
}

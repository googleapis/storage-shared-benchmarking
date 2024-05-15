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

import java.lang.management.MemoryType;
import java.lang.management.MemoryUsage;
import java.util.Comparator;

/**
 * Simple data class to hold onto values related to a memory pools usage, while providing some
 * convenience methods.
 *
 * @see MemoryUsage
 */
public final class MemoryPoolUsage implements Comparable<MemoryPoolUsage> {

  public static final Comparator<MemoryPoolUsage> COMP =
      Comparator.comparing(MemoryPoolUsage::getName);
  private final String name;
  private final MemoryType type;
  private final long init;
  private final long used;
  private final long committed;
  private final long max;

  private MemoryPoolUsage(
      String name, MemoryType type, long init, long used, long committed, long max) {
    this.name = name;
    this.type = type;
    this.init = init;
    this.used = used;
    this.committed = committed;
    this.max = max;
  }

  public String getName() {
    return name;
  }

  public MemoryType getType() {
    return type;
  }

  public long getInit() {
    return init;
  }

  public long getUsed() {
    return used;
  }

  public long getCommitted() {
    return committed;
  }

  public long getMax() {
    return max;
  }

  public MemoryPoolUsage sub(MemoryPoolUsage other) {
    return new MemoryPoolUsage(
        this.name,
        this.type,
        this.init - other.init,
        this.used - other.used,
        this.committed - other.committed,
        this.max - other.max);
  }

  @Override
  public int compareTo(MemoryPoolUsage o) {
    return COMP.compare(this, o);
  }

  @Override
  public String toString() {
    return String.format(
        "(%8s)%-35s{init: %,14d, used: %,14d, committed: %,14d,  max: %,14d}",
        type.name(), name, init, used, committed, max);
  }

  public static MemoryPoolUsage of(String name, MemoryType type, MemoryUsage usage) {
    return new MemoryPoolUsage(
        name, type, usage.getInit(), usage.getUsed(), usage.getCommitted(), usage.getMax());
  }
}

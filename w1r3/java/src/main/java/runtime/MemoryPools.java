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

import java.lang.management.ManagementFactory;
import java.lang.management.MemoryPoolMXBean;
import java.util.ArrayList;
import java.util.List;

/** Utility class to takes snapshots of memory pool usage for JVM memory monitoring */
public final class MemoryPools {
  private static final List<MemoryPoolMXBean> BEANS = ManagementFactory.getMemoryPoolMXBeans();

  private MemoryPools() {}

  /** Generate a snapshot of each memory pools usage */
  public static List<MemoryPoolUsage> getUsage() {

    // https://openjdk.org/jeps/197
    List<MemoryPoolUsage> memoryPoolUsages = new ArrayList<>();
    for (MemoryPoolMXBean bean : BEANS) {
      memoryPoolUsages.add(MemoryPoolUsage.of(bean.getName(), bean.getType(), bean.getUsage()));
    }

    memoryPoolUsages.sort(MemoryPoolUsage.COMP);

    return memoryPoolUsages;
  }
}

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
import java.lang.management.ThreadMXBean;

/** Utility class to access the amount of cpu time consumed by the running process. */
public final class CpuTime {
  private static final ThreadMXBean BEAN;

  static {
    BEAN = ManagementFactory.getThreadMXBean();
    if (!BEAN.isThreadCpuTimeEnabled()) {
      BEAN.setThreadCpuTimeEnabled(true);
    }
  }

  private CpuTime() {}

  /**
   * Return the total number of {@code user} and {@code sys} cpu nanoseconds used across all current
   * threads of the running process.
   */
  public static long getTotalCpuNanos() {
    long[] allThreadIds = BEAN.getAllThreadIds();
    long totalCpuNanos = 0;
    for (long threadId : allThreadIds) {
      // https://docs.oracle.com/en/java/javase/11/docs/api/java.management/java/lang/management/ThreadMXBean.html#getThreadCpuTime(long)
      // in temurin 11 and 21 this is both user+sys time
      long threadCpuTime = BEAN.getThreadCpuTime(threadId);
      if (threadCpuTime > -1) {
        totalCpuNanos = Math.addExact(totalCpuNanos, threadCpuTime);
      }
    }
    return totalCpuNanos;
  }
}

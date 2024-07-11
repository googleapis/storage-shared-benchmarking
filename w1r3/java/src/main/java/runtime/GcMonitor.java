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

import static com.sun.management.GarbageCollectionNotificationInfo.GARBAGE_COLLECTION_NOTIFICATION;
import static java.lang.management.MemoryType.HEAP;

import com.sun.management.GarbageCollectionNotificationInfo;
import com.sun.management.GcInfo;
import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryPoolMXBean;
import java.lang.management.MemoryUsage;
import java.time.Duration;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Collectors;
import javax.management.Notification;
import javax.management.NotificationEmitter;
import javax.management.NotificationListener;
import javax.management.openmbean.CompositeData;

public final class GcMonitor implements NotificationListener {

  private static final long SLEEP_INTERVAL = Duration.ofMillis(5).toMillis();
  private static final long SLEEP_MAX_TIMEOUT = Duration.ofSeconds(5).toNanos();
  private static final Set<String> MONITORED_POOL_NAMES;

  static {
    TreeSet<String> tmp = new TreeSet<>();
    List<MemoryPoolMXBean> pools = ManagementFactory.getMemoryPoolMXBeans();
    for (MemoryPoolMXBean pool : pools) {
      if (pool.getType() == HEAP) {
        tmp.add(pool.getName());
      }
    }
    MONITORED_POOL_NAMES = Collections.unmodifiableSet(tmp);
  }

  private static final GcMonitor INSTANCE = new GcMonitor();

  static {
    // must happen after the singleton instance is initialized
    GcMonitor.register();
  }

  private final AtomicLong gcCount = new AtomicLong(0);
  private final AtomicReference<GcEvent> last = new AtomicReference<>();

  private GcMonitor() {}

  @Override
  public void handleNotification(Notification notification, Object handback) {
    gcCount.getAndIncrement();
    Object userData = notification.getUserData();
    if (notification.getType().equals(GARBAGE_COLLECTION_NOTIFICATION)
        && userData instanceof CompositeData) {
      CompositeData data = (CompositeData) userData;
      GarbageCollectionNotificationInfo gcni = GarbageCollectionNotificationInfo.from(data);
      GcInfo gcInfo = gcni.getGcInfo();
      Map<String, MemoryUsage> before = gcInfo.getMemoryUsageBeforeGc();
      Map<String, MemoryUsage> after = gcInfo.getMemoryUsageAfterGc();
      GcEvent gcEvent =
          GcEvent.of(
              System.nanoTime(),
              gcCount.get(),
              MONITORED_POOL_NAMES.stream()
                  .map(poolName -> MemoryPoolUsage.of(poolName, HEAP, before.get(poolName)))
                  .collect(Collectors.toList()),
              MONITORED_POOL_NAMES.stream()
                  .map(poolName -> MemoryPoolUsage.of(poolName, HEAP, after.get(poolName)))
                  .collect(Collectors.toList()));
      last.set(gcEvent);
    }
  }

  private GcEvent internalAwaitGc() throws InterruptedException {
    final long begin = System.nanoTime();
    Runtime.getRuntime().gc();
    GcEvent gcEvent;
    while ((gcEvent = last.get()) != null && gcEvent.getTimestampNs() < begin) {
      long split = System.nanoTime();
      if (split - begin > SLEEP_MAX_TIMEOUT) {
        // if we can't get a new value within 5 second, break out and return what we have
        break;
      }
      Thread.sleep(SLEEP_INTERVAL);
    }
    return gcEvent;
  }

  public static GcEvent awaitGc() throws InterruptedException {
    return INSTANCE.internalAwaitGc();
  }

  private static void register() {
    List<GarbageCollectorMXBean> garbageCollectorMXBeans =
        ManagementFactory.getGarbageCollectorMXBeans();
    for (GarbageCollectorMXBean gcBean : garbageCollectorMXBeans) {
      if (gcBean instanceof NotificationEmitter) {
        NotificationEmitter emitter = (NotificationEmitter) gcBean;
        emitter.addNotificationListener(INSTANCE, null, null);
      }
    }
  }
}

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

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

/**
 * Class that can be used to read the {@code /proc/PID/smaps_rollup} from <a
 * href="https://man7.org/linux/man-pages/man5/proc.5.html">procfs</a> to determine the Resident Set
 * Size (RSS) and Persistent Set Size (PSS) of the current process.
 */
public final class SmapsRollup {

  private static final Path SMAPS_PATH;

  static {
    // only works on java9+
    long pid = ProcessHandle.current().pid();
    SMAPS_PATH = Paths.get(String.format("/proc/%d/smaps_rollup", pid));
  }

  private SmapsRollup() {}

  public static SetSize get() throws IOException {
    // read all lines completes in < 12us, if we were to try and do it ourselves with a channel
    // it takes around 50us and comes with the disadvantage of having to do byte processing manually
    List<String> strings = Files.readAllLines(SMAPS_PATH);
    long rss = -1;
    long pss = -1;
    for (String s : strings) {
      if (s.startsWith("Rss:")) {
        String digits = s.substring(4, s.length() - 2).trim();
        rss = Long.parseLong(digits);
      } else if (s.startsWith("Pss:")) {
        String digits = s.substring(4, s.length() - 2).trim();
        pss = Long.parseLong(digits);
      } else if (rss > -1 && pss > -1) {
        break;
      }
    }
    return new SetSize(rss, pss);
  }
}

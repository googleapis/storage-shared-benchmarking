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

public final class SetSize {

  private final long rss;
  private final long pss;

  public SetSize(long rss, long pss) {
    this.rss = rss;
    this.pss = pss;
  }

  public long getRss() {
    return rss;
  }

  public long getPss() {
    return pss;
  }

  SetSize sub(SetSize other) {
    return new SetSize(rss - other.rss, pss - other.pss);
  }

  @Override
  public String toString() {
    return String.format("rss: %,14d kB, pss: %,14d kB", rss, pss);
  }
}

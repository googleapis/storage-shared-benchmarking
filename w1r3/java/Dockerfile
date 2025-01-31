# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM maven:3.9.9-eclipse-temurin-11 AS build

WORKDIR /var/tmp/build
COPY w1r3/java/pom.xml /var/tmp/build/w1r3/java/pom.xml
# Manually install the dependencies to speed up the builds on Cloud Build.
# Kaniko caches this layer and the build does not need to download the
# dependencies each time.
RUN env -C w1r3/java mvn dependency:resolve-plugins
RUN env -C w1r3/java mvn dependency:resolve
RUN env -C w1r3/java mvn verify
COPY .git/ /var/tmp/build/.git
COPY w1r3/ /var/tmp/build/w1r3
RUN env -C w1r3/java mvn -DGIT_SHA=$(git rev-parse --verify HEAD) package

FROM eclipse-temurin:21.0.6_7-jdk-jammy

COPY --from=build  /var/tmp/build/w1r3/java/target/w1r3-0.0.1-SNAPSHOT.jar /r/w1r3.jar

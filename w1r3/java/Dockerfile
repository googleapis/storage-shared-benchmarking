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

FROM maven:3.9.8-eclipse-temurin-11 AS build

WORKDIR /var/tmp/build
COPY pom.xml /var/tmp/build/
# Manually install the dependencies to speed up the builds on Cloud Build.
# Kaniko caches this layer and the build does not need to download the
# dependencies each time.
RUN mvn dependency:resolve-plugins
RUN mvn dependency:resolve
RUN mvn install
COPY src/main /var/tmp/build/src/main
RUN mvn package

FROM eclipse-temurin:21.0.4_7-jdk-jammy

COPY --from=build  /var/tmp/build/target/w1r3-0.0.1-SNAPSHOT.jar /r/w1r3.jar

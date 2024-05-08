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

FROM alpine:3.19 AS build

# Install the minimal development tools:
RUN apk update && \
    apk add maven openjdk11

WORKDIR /var/tmp/build
COPY pom.xml /var/tmp/build/
RUN mvn dependency:resolve-plugins
RUN mvn dependency:resolve
RUN mvn install
COPY src/main/java/W1R3.java /var/tmp/build/src/main/java/
RUN mvn package

FROM openjdk:19-jdk-alpine

COPY --from=build  /var/tmp/build/target/w1r3-0.0.1-SNAPSHOT.jar /r/w1r3.jar

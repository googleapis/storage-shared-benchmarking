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

FROM golang:1.22 AS build

WORKDIR /var/tmp/build/w1r3
COPY w1r3/ /var/tmp/build/w1r3/w1r3
RUN go -C w1r3/go mod download
COPY .git/ /var/tmp/build/w1r3/.git
RUN go -C w1r3/go build

FROM alpine:3.20 AS deploy

RUN apt update && \
    apt install -y ca-certificates

COPY --from=build /var/tmp/build/w1r3/w1r3/go/w1r3 /r/w1r3

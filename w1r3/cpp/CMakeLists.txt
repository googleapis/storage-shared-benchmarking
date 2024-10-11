# ~~~
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ~~~

cmake_minimum_required(VERSION 3.24...3.28)
project(w1r3-cpp CXX)

find_package(google_cloud_cpp_monitoring CONFIG REQUIRED)
find_package(google_cloud_cpp_storage CONFIG REQUIRED)
find_package(google_cloud_cpp_storage_grpc CONFIG REQUIRED)
find_package(google_cloud_cpp_opentelemetry CONFIG REQUIRED)
find_package(
    Boost
    COMPONENTS program_options
    REQUIRED)

# We need to capture the Protobuf version in the code. Unfortunately Protobuf
# does not (yet) expose its version via macros or functions. We use a bit of
# CMake code to capture the version instead.
find_package(Protobuf CONFIG REQUIRED)

find_package(Git REQUIRED)
# Capture the output from `git rev-parse HEAD`.
execute_process(
    COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE W1R3_VERSION
    ERROR_VARIABLE W1R3_VERSION
    RESULT_VARIABLE ERROR_CODE
    OUTPUT_STRIP_TRAILING_WHITESPACE)
# Manual builds on GCB may not have a `.git` directory.
if (ERROR_CODE)
    message("Error running git: ${W1R3_VERSION} ${ERROR_CODE}")
    set(W1R3_VERSION "unknown")
endif ()

add_executable(w1r3 w1r3.cc)
target_compile_features(w1r3 PRIVATE cxx_std_20)
target_compile_definitions(
    w1r3 PRIVATE SSB_PROTOBUF_VERSION="${Protobuf_VERSION}"
                 SSB_W1R3_VERSION="${W1R3_VERSION}")
target_link_libraries(
    w1r3
    PRIVATE google-cloud-cpp::storage_grpc
            google-cloud-cpp::storage
            google-cloud-cpp::monitoring
            google-cloud-cpp::opentelemetry
            opentelemetry-cpp::trace
            opentelemetry-cpp::metrics
            opentelemetry-cpp::ostream_metrics_exporter
            Boost::program_options)

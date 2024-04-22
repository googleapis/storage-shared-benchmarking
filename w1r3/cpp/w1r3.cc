// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <google/cloud/internal/build_info.h>
#include <google/cloud/internal/compiler_info.h>
#include <google/cloud/project.h>
#include <google/cloud/version.h>
#include <boost/lexical_cast.hpp>
#include <boost/program_options.hpp>
#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#include <grpcpp/grpcpp.h>
#include <opentelemetry/context/context.h>
#include <opentelemetry/metrics/provider.h>
#include <opentelemetry/sdk/metrics/meter_provider.h>
#include <opentelemetry/sdk/metrics/view/instrument_selector_factory.h>
#include <opentelemetry/sdk/metrics/view/meter_selector_factory.h>
#include <opentelemetry/sdk/metrics/view/view_factory.h>
#include <opentelemetry/trace/provider.h>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <exception>
#include <functional>
#include <iostream>
#include <map>
#include <numeric>
#include <random>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <tuple>
#include <utility>
#include <vector>

auto constexpr kKB = 1'000;
auto constexpr kMB = kKB * kKB;
auto constexpr kKiB = 1024;
auto constexpr kMiB = kKiB * kKiB;

using namespace std::literals;
auto constexpr kTransportJson = "JSON"sv;
auto constexpr kTransportGrpc = "GRPC+CFE"sv;
auto constexpr kTransportDirectPath = "GRPC+DP"sv;

auto constexpr kDefaultIterations = 1'000'000;

namespace gc = ::google::cloud;

auto parse_args(int argc, char* argv[]) {
  namespace po = boost::program_options;
  po::options_description desc(
      "A simple publisher application with Open Telemetery enabled");
  // The following empty line comments are for readability.
  desc.add_options()                      //
      ("help,h", "produce help message")  //
      // Benchmark options
      ("bucket", po::value<std::string>()->required(),
       "the name of a Google Cloud Storage bucket. The benchmark uses this"
       " bucket to upload and download objects and measures the latency.")  //
      ("deployment", po::value<std::string>()->default_value("development"),
       "a short string describing where the benchmark is deployed, e.g."
       " development, or GKE, or GCE.")  //
      ("iterations", po::value<int>()->default_value(kDefaultIterations),
       "the number of iterations before exiting the test")  //
      ("object-sizes", po::value<std::vector<std::int64_t>>()->multitoken(),
       "the object sizes used in the benchmark.")  //
      ("transports", po::value<std::vector<std::string>>()->multitoken(),
       "the transports used in the benchmark.")  //
      ("data-buffer-size", po::value<std::size_t>()->default_value(128 * kMiB),
       "PUT size for resumable uploads")("workers",
                                         po::value<int>()->default_value(1),
                                         "the number of worker threads.")  //
      // Open Telemetry Processor options
      ("project-id", po::value<std::string>()->required(),
       "a Google Cloud Project id. The benchmark sends its results to this"
       " project as Cloud Monitoring metrics and Cloud Trace traces.")  //
      ("tracing-rate", po::value<double>()->default_value(1.0),
       "otel::BasicTracingRateOption value")  //
      ("max-queue-size", po::value<int>()->default_value(2048),
       "set the max queue size for open telemetery")  //
      ("max-batch-messages", po::value<std::size_t>(),
       "pubsub::MaxBatchMessagesOption value");

  po::variables_map vm;
  po::store(po::command_line_parser(argc, argv).options(desc).run(), vm);
  if (vm.count("help") || argc == 1) {
    std::cerr << "Usage: " << argv[0] << "\n";
    std::cerr << desc << "\n";
    std::exit(argc == 1 ? EXIT_FAILURE : EXIT_SUCCESS);
  }
  po::notify(vm);
  return vm;
}

auto get_object_sizes(boost::program_options::variables_map const& vm) {
  auto const l = vm.find("object-sizes");
  if (l == vm.end()) {
    return std::vector<std::int64_t>{100 * kKB, 2 * kMiB, 100 * kMB};
  }
  return vm["object-sizes"].as<std::vector<std::int64_t>>();
}

auto get_transports(boost::program_options::variables_map const& vm) {
  auto const l = vm.find("transports");
  if (l == vm.end()) {
    return std::vector<std::string>{
        std::string(kTransportJson),
        std::string(kTransportDirectPath),
        std::string(kTransportGrpc),
    };
  }
  return vm["transports"].as<std::vector<std::string>>();
}

auto make_prng_bits_generator() {
  // Random number initialization in C++ is more tedious than it should be.
  // First you get some entropy from the random device. We don't need too much,
  // just a word will do:
  auto entropy = std::vector<unsigned int>({std::random_device{}()});
  // Then you shuffle these bits. The recommended PRNG has poor behavior if
  // too many of the seed bits are all zeroes. This shuffling step avoids that
  // problem.
  auto seq = std::seed_seq(entropy.begin(), entropy.end());
  // Now initialize the PRNG.
  return std::mt19937_64(seq);
}

auto generate_uuid(std::mt19937_64& gen) {
  using uuid_generator = boost::uuids::basic_random_generator<std::mt19937_64>;
  return boost::uuids::to_string(uuid_generator{gen}());
}

int main(int argc, char* argv[]) try {
  auto const vm = parse_args(argc, argv);

  auto const project = gc::Project(vm["project-id"].as<std::string>());
  auto generator = make_prng_bits_generator();
  auto const instance = generate_uuid(generator);

  auto const bucket_name = vm["bucket"].as<std::string>();
  auto const object_sizes = get_object_sizes(vm);
  auto const transports = get_transports(vm);
  auto const deployment = vm["deployment"].as<std::string>();

  auto join = [](auto collection) {
    if (collection.empty()) return std::string{};
    return std::accumulate(std::next(collection.begin()), collection.end(),
                           boost::lexical_cast<std::string>(collection.front()),
                           [](auto a, auto const& b) {
                             a += ",";
                             a += boost::lexical_cast<std::string>(b);
                             return a;
                           });
  };
  // Using the `internal` namespace is frowned upon. The C++ SDK team may change
  // the types and functions in this namespace at any time. If this ever breaks
  // we will find out at compile time, and will need to detect the compiler and
  // build flags ourselves.
  namespace gci = ::google::cloud::internal;
  std::cout << "## Starting continuous GCS C++ SDK benchmark"              //
            << "\n# object-sizes: " << join(object_sizes)                  //
            << "\n# transports: " << join(transports)                      //
            << "\n# project-id: " << project                               //
            << "\n# bucket: " << bucket_name                               //
            << "\n# deployment: " << deployment                            //
            << "\n# instance: " << instance                                //
            << "\n# C++ SDK version: " << gc::version_string()             //
            << "\n# C++ SDK Compiler: " << gci::CompilerId()               //
            << "\n# C++ SDK Compiler Version: " << gci::CompilerVersion()  //
            << "\n# C++ SDK Compiler Flags: " << gci::compiler_flags()     //
            << "\n# gRPC version: " << grpc::Version()                     //
            << "\n# Protobuf version: " << SSB_PROTOBUF_VERSION            //
            << std::endl;                                                  //

  return EXIT_SUCCESS;
} catch (std::exception const& ex) {
  std::cerr << "Standard C++ exception caught " << ex.what() << "\n";
  return EXIT_FAILURE;
} catch (...) {
  std::cerr << "Unknown exception caught\n";
  return EXIT_FAILURE;
}

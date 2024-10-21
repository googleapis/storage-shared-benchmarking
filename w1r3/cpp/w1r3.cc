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
#include <google/cloud/opentelemetry/configure_basic_tracing.h>
#include <google/cloud/opentelemetry/monitoring_exporter.h>
#include <google/cloud/opentelemetry/resource_detector.h>
#include <google/cloud/opentelemetry_options.h>
#include <google/cloud/project.h>
#include <google/cloud/storage/client.h>
#include <google/cloud/storage/grpc_plugin.h>
#include <google/cloud/storage/options.h>
#include <google/cloud/version.h>
#include <boost/lexical_cast.hpp>
#include <boost/program_options.hpp>
#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#include <curl/curlver.h>
#include <grpcpp/grpcpp.h>
#include <opentelemetry/context/context.h>
#include <opentelemetry/metrics/provider.h>
#include <opentelemetry/sdk/common/attribute_utils.h>
#include <opentelemetry/sdk/metrics/export/metric_producer.h>
#include <opentelemetry/sdk/metrics/export/periodic_exporting_metric_reader_factory.h>
#include <opentelemetry/sdk/metrics/export/periodic_exporting_metric_reader_options.h>
#include <opentelemetry/sdk/metrics/meter_provider.h>
#include <opentelemetry/sdk/metrics/meter_provider_factory.h>
#include <opentelemetry/sdk/metrics/view/instrument_selector_factory.h>
#include <opentelemetry/sdk/metrics/view/meter_selector_factory.h>
#include <opentelemetry/sdk/metrics/view/view_factory.h>
#include <opentelemetry/sdk/resource/semantic_conventions.h>
#include <opentelemetry/trace/provider.h>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <exception>
#include <functional>
#include <iostream>
#include <map>
#include <new>
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
#include <sys/resource.h>

namespace {

using namespace std::literals;
auto constexpr kSingleShot = "SINGLE-SHOT"sv;
auto constexpr kResumable = "RESUMABLE"sv;
auto constexpr kTransportJson = "JSON"sv;
auto constexpr kTransportGrpc = "GRPC+CFE"sv;
auto constexpr kTransportDirectPath = "GRPC+DP"sv;

auto constexpr kKB = 1'000;
auto constexpr kMB = kKB * kKB;
auto constexpr kKiB = 1024;
auto constexpr kMiB = kKiB * kKiB;

auto constexpr kAppName = "w1r3"sv;
auto constexpr kLatencyHistogramName = "ssb/w1r3/latency";
auto constexpr kLatencyDescription =
    "Operation latency as measured by the benchmark.";
auto constexpr kLatencyHistogramUnit = "s";

auto constexpr kCpuHistogramName = "ssb/w1r3/cpu";
auto constexpr kCpuDescription =
    "CPU usage per byte as measured by the benchmark.";
auto constexpr kCpuHistogramUnit = "ns/B{CPU}";

auto constexpr kMemoryHistogramName = "ssb/w1r3/memory";
auto constexpr kMemoryDescription =
    "Memory usage per byte as measured by the benchmark.";
auto constexpr kMemoryHistogramUnit = "1{memory}";

auto constexpr kVersion = "1.2.0";
auto constexpr kSchema = "https://opentelemetry.io/schemas/1.2.0";

auto constexpr kDefaultIterations = 1'000'000;
auto constexpr kDefaultSampleRate = 0.05;

namespace gc = ::google::cloud;
using dseconds = std::chrono::duration<double, std::ratio<1>>;

boost::program_options::variables_map parse_args(int argc, char* argv[]);

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

std::map<std::string, google::cloud::storage::Client> make_clients(
    boost::program_options::variables_map const& vm);

using uploader_function = std::function<gc::Status(
    gc::storage::Client& client, std::string const& bucket_name,
    std::string const& object_name, std::int64_t object_size,
    std::span<char> buffer)>;

std::map<std::string, uploader_function> make_uploaders(
    boost::program_options::variables_map const&);

std::string discover_region();

std::unique_ptr<opentelemetry::metrics::MeterProvider> make_meter_provider(
    google::cloud::Project const& project, std::string const& instance);

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

using histogram_ptr =
    opentelemetry::nostd::shared_ptr<opentelemetry::metrics::Histogram<double>>;

struct config {
  std::map<std::string, google::cloud::storage::Client> clients;
  std::map<std::string, uploader_function> uploaders;
  std::vector<std::int64_t> object_sizes;
  std::string bucket_name;
  std::string deployment;
  std::string instance;
  std::string region;
  int iterations;
  histogram_ptr latency;
  histogram_ptr cpu;
  histogram_ptr memory;
};

void worker(std::shared_ptr<std::vector<char>> data, config cfg);

}  // namespace

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
            << "\n# Version: " << SSB_W1R3_VERSION                         //
            << "\n# C++ SDK version: " << gc::version_string()             //
            << "\n# C++ SDK Compiler: " << gci::CompilerId()               //
            << "\n# C++ SDK Compiler Version: " << gci::CompilerVersion()  //
            << "\n# C++ SDK Compiler Flags: " << gci::compiler_flags()     //
            << "\n# gRPC version: " << grpc::Version()                     //
            << "\n# Protobuf version: " << SSB_PROTOBUF_VERSION            //
            << "\n# Tracing Rate: " << vm["tracing-rate"].as<double>()     //
            << std::endl;                                                  //

  auto const tracing = gc::otel::ConfigureBasicTracing(
      project, gc::Options{}.set<gc::otel::BasicTracingRateOption>(
                   vm["tracing-rate"].as<double>()));

  auto provider =
      make_meter_provider(google::cloud::Project(project), instance);

  // Create a histogram to capture the performance results.
  auto meter = provider->GetMeter(std::string{kAppName}, kVersion, kSchema);
  histogram_ptr latency = meter->CreateDoubleHistogram(
      kLatencyHistogramName, kLatencyDescription, kLatencyHistogramUnit);
  histogram_ptr cpu = meter->CreateDoubleHistogram(
      kCpuHistogramName, kCpuDescription, kCpuHistogramUnit);
  histogram_ptr memory = meter->CreateDoubleHistogram(
      kMemoryHistogramName, kMemoryDescription, kMemoryHistogramUnit);

  // Create some random data to upload. This is shared across all workers.
  auto const data_buffer_size =
      *std::max_element(object_sizes.begin(), object_sizes.end());
  auto data = std::make_shared<std::vector<char>>(data_buffer_size);
  std::generate(data->begin(), data->end(), [&generator]() {
    return std::uniform_int_distribution<char>(0, 255)(generator);
  });

  auto cfg = config{
      .clients = make_clients(vm),
      .uploaders = make_uploaders(vm),
      .object_sizes = std::move(object_sizes),
      .bucket_name = std::move(bucket_name),
      .deployment = deployment,
      .instance = instance,
      .region = discover_region(),
      .iterations = vm["iterations"].as<int>(),
      .latency = std::move(latency),
      .cpu = std::move(cpu),
      .memory = std::move(memory),
  };

  auto const worker_count = vm["workers"].as<int>();
  std::vector<std::jthread> workers;
  for (int i = 0; i != worker_count; ++i) {
    workers.push_back(std::jthread([&] { worker(data, cfg); }));
  }

  return EXIT_SUCCESS;
} catch (std::exception const& ex) {
  std::cerr << "Standard C++ exception caught " << ex.what() << "\n";
  return EXIT_FAILURE;
} catch (...) {
  std::cerr << "Unknown exception caught\n";
  return EXIT_FAILURE;
}

namespace {

template <typename Collection>
auto pick_one(std::mt19937_64& generator, Collection const& collection) {
  auto index = std::uniform_int_distribution<std::size_t>(
      0, std::size(collection) - 1)(generator);
  return *std::next(std::begin(collection), index);
}

auto make_object_name(std::mt19937_64& generator) {
  return generate_uuid(generator);
}

auto read_object(gc::storage::Client& client, std::string const& bucket_name,
                 std::string const& object_name) {
  auto is = client.ReadObject(bucket_name, object_name);
  std::vector<char> discard(2 * kMiB);
  while (true) {
    is.read(discard.data(), discard.size());
    if (!is.good()) break;
  }
  return is.status();
}

// We instrument `operator new` to track the number of allocated bytes. This
// global is used to track the value.
std::atomic<std::uint64_t> allocated_bytes{0};

class usage {
 public:
  usage()
      : mem_(mem_now()),
        clock_(std::chrono::steady_clock::now()),
        cpu_(cpu_now()) {}

  void record(config const& cfg, std::uint64_t object_size, auto span,
              auto attributes) const {
    auto const cpu_usage = cpu_now() - cpu_;
    auto const elapsed = std::chrono::steady_clock::now() - clock_;
    auto const mem_usage = mem_now() - mem_;

    auto scale = [object_size](auto value) {
      if (object_size == 0) return static_cast<double>(value);
      return static_cast<double>(value) / static_cast<double>(object_size);
    };

    cfg.latency->Record(
        std::chrono::duration_cast<dseconds>(elapsed).count(), attributes,
        opentelemetry::context::Context{}.SetValue("span", span));
    cfg.cpu->Record(scale(cpu_usage.count()), attributes,
                    opentelemetry::context::Context{}.SetValue("span", span));
    cfg.memory->Record(
        scale(mem_usage), attributes,
        opentelemetry::context::Context{}.SetValue("span", span));
    span->End();
  }

 private:
  static std::uint64_t mem_now() { return allocated_bytes.load(); }

  static auto as_nanoseconds(struct timeval const& t) {
    using ns = std::chrono::nanoseconds;
    return ns(std::chrono::seconds(t.tv_sec)) +
           ns(std::chrono::microseconds(t.tv_usec));
  }

  static std::chrono::nanoseconds cpu_now() {
    struct rusage ru {};
    (void)getrusage(RUSAGE_SELF, &ru);
    return as_nanoseconds(ru.ru_utime) + as_nanoseconds(ru.ru_stime);
  }

  std::uint64_t mem_;
  std::chrono::steady_clock::time_point clock_;
  std::chrono::nanoseconds cpu_;
};

void worker(std::shared_ptr<std::vector<char>> data, config cfg) {
  // Obtain a tracer for the Shared Storage Benchmarks. We create traces that
  // logically connect the client library traces for uploads and downloads.
  auto tracer =
      opentelemetry::trace::Provider::GetTracerProvider()->GetTracer("ssb");

  auto generator = make_prng_bits_generator();
  // Opentelemetry captures all string values as `std::string_view`. We need
  // to capture these strings in variables with lifetime longer than the loop.
  auto const sdk_version = gc::version_string();
  auto const grpc_version = grpc::Version();

  for (int i = 0; i != cfg.iterations; ++i) {
    auto const object_name = make_object_name(generator);
    auto const object_size = pick_one(generator, cfg.object_sizes);
    auto client = pick_one(generator, cfg.clients);
    auto const uploader = pick_one(generator, cfg.uploaders);

    auto common_attributes = [&] {
      return std::vector<std::pair<opentelemetry::nostd::string_view,
                                   opentelemetry::common::AttributeValue>>{
          {"ssb.language", "cpp"},
          {"ssb.object-size", object_size},
          {"ssb.transport", client.first},
          {"ssb.deployment", cfg.deployment},
          {"ssb.instance", cfg.instance},
          {"ssb.region", cfg.region},
          {"ssb.version", SSB_W1R3_VERSION},
          {"ssb.version.sdk", sdk_version},
          {"ssb.version.grpc", grpc_version},
          {"ssb.version.protobuf", SSB_PROTOBUF_VERSION},
          {"ssb.version.http-client", LIBCURL_VERSION},
      };
    }();
    auto with_op = [common_attributes](opentelemetry::nostd::string_view op) {
      auto attr = common_attributes;
      attr.emplace_back("ssb.op", op);
      auto const is_read =
          std::string_view(op.data(), op.size()).starts_with("READ");
      attr.emplace_back("ssb.transfer.type", is_read ? "DOWNLOAD" : "UPLOAD");
      return attr;
    };
    auto as_attributes = [](auto const& attr) {
      using value_type = typename std::decay_t<decltype(attr)>::value_type;
      using span_t = opentelemetry::nostd::span<value_type const>;
      return opentelemetry::common::MakeAttributes(
          span_t(attr.data(), attr.size()));
    };

    auto iteration_span = tracer->StartSpan(
        "ssb::iteration",
        opentelemetry::common::MakeAttributes(common_attributes));
    auto iteration = tracer->WithActiveSpan(iteration_span);

    {
      auto upload_attributes = with_op(uploader.first);
      auto upload_span =
          tracer->StartSpan("ssb::upload", as_attributes(upload_attributes));
      auto upload = tracer->WithActiveSpan(upload_span);
      auto const t = usage();
      auto status = uploader.second(client.second, cfg.bucket_name, object_name,
                                    object_size, *data);
      if (!status.ok()) {
        upload_span->SetStatus(opentelemetry::trace::StatusCode::kError,
                               status.message());
        upload_span->End();
        continue;
      }
      t.record(cfg, object_size, upload_span, as_attributes(upload_attributes));
    }

    for (auto const* op : {"READ[0]", "READ[1]", "READ[2]"}) {
      auto download_attributes = with_op(op);
      auto download_span = tracer->StartSpan(
          "ssb::download", as_attributes(download_attributes));
      auto download = tracer->WithActiveSpan(download_span);
      auto const t = usage();
      auto status = read_object(client.second, cfg.bucket_name, object_name);
      if (!status.ok()) {
        download_span->SetStatus(opentelemetry::trace::StatusCode::kError,
                                 status.message());
        download_span->End();
        continue;
      }
      t.record(cfg, object_size, download_span,
               as_attributes(download_attributes));
    }

    // Delete the object after the iteration span is marked as done.
    (void)client.second.DeleteObject(cfg.bucket_name, object_name);

    iteration_span->End();
  }
}

std::map<std::string, google::cloud::storage::Client> make_clients(
    boost::program_options::variables_map const& vm) {
  // Set the upload buffer size to the minimum possible on resumable uploads.
  // With this setting any buffer that is large enough will create a `PUT` or
  // `WriteObject` request.
  auto const options = gc::Options{}
                           .set<gc::storage::UploadBufferSizeOption>(256 * kKiB)
                           .set<gc::OpenTelemetryTracingOption>(true);
  // Use lambdas to create the clients only if needed.
  auto make_json = [&options]() { return gc::storage::Client(options); };
  auto make_grpc = [&options]() {
    return gc::storage::MakeGrpcClient(
        gc::Options(options).set<gc::EndpointOption>(
            "storage.googleapis.com"));
  };
  auto make_dp = [&options]() {
    return gc::storage::MakeGrpcClient(
        gc::Options(options).set<gc::EndpointOption>(
            "google-c2p:///storage.googleapis.com"));
  };
  std::map<std::string, gc::storage::Client> clients;
  for (auto const& name : get_transports(vm)) {
    if (name == kTransportJson) {
      clients.emplace(name, make_json());
    } else if (name == kTransportGrpc) {
      clients.emplace(name, make_grpc());
    } else if (name == kTransportDirectPath) {
      clients.emplace(name, make_dp());
    } else {
      throw std::runtime_error("unknown transport name " + name);
    }
  }
  return clients;
}

auto insert_object(gc::storage::Client& client, std::string const& bucket_name,
                   std::string const& object_name, std::int64_t object_size,
                   std::span<char> buffer) {
  if (object_size > buffer.size()) {
    return gc::Status(gc::StatusCode::kInvalidArgument,
                      "object size is too large for InsertObject() calls");
  }
  return client
      .InsertObject(bucket_name, object_name,
                    std::string_view{buffer.data(),
                                     static_cast<std::size_t>(object_size)})
      .status();
}

auto write_object(gc::storage::Client& client, std::string const& bucket_name,
                  std::string const& object_name, std::int64_t object_size,
                  std::span<char> buffer) {
  auto os = client.WriteObject(bucket_name, object_name);
  auto offset = std::int64_t{0};
  while (offset < object_size && !os.bad()) {
    auto const n = std::min(object_size - offset,
                            static_cast<std::int64_t>(buffer.size()));
    os.write(buffer.data(), n);
    offset += n;
  }
  os.Close();
  return os.metadata().status();
}

std::map<std::string, uploader_function> make_uploaders(
    boost::program_options::variables_map const&) {
  return std::map<std::string, uploader_function>{
      {std::string(kSingleShot), insert_object},
      {std::string(kResumable), write_object},
  };
}

std::string discover_region() {
  namespace sc = opentelemetry::sdk::resource::SemanticConventions;
  auto detector = google::cloud::otel::MakeResourceDetector();
  auto detected_resource = detector->Detect();
  for (auto const& [k, v] : detected_resource.GetAttributes()) {
    if (k == sc::kCloudRegion) 
      return std::get<std::string>(v);
  }
  return std::string("unknown");
}

auto make_resource(std::string const& instance) {
  // Create an OTel resource that maps to `generic_task` on GCM.
  namespace sc = opentelemetry::sdk::resource::SemanticConventions;
  auto resource_attributes = opentelemetry::sdk::resource::ResourceAttributes();
  resource_attributes.SetAttribute(sc::kServiceNamespace, "default");
  resource_attributes.SetAttribute(sc::kServiceName, std::string(kAppName));
  resource_attributes.SetAttribute(sc::kServiceInstanceId, instance);

  auto detector = google::cloud::otel::MakeResourceDetector();
  auto detected_resource = detector->Detect();
  for (auto const& [k, v] : detected_resource.GetAttributes()) {
    if (k == sc::kCloudRegion) {
      resource_attributes.SetAttribute(k, std::get<std::string>(v));
    } else if (k == sc::kCloudAvailabilityZone) {
      resource_attributes.SetAttribute(k, std::get<std::string>(v));
    }
  }
  return opentelemetry::sdk::resource::Resource::Create(resource_attributes);
}

auto make_latency_histogram_boundaries() {
  using namespace std::chrono_literals;
  // Cloud Monitoring only supports up to 200 buckets per histogram, we have
  // to choose them carefully.
  std::vector<double> boundaries;
  auto boundary = 0ms;
  auto increment = 2ms;
  // For the first 100ms use 2ms buckets. We need higher resolution in this
  // area for 100KB uploads and downloads.
  for (int i = 0; i != 50; ++i) {
    boundaries.push_back(
        std::chrono::duration_cast<dseconds>(boundary).count());
    boundary += increment;
  }
  // The remaining buckets are 10ms wide, and then 20ms, and so forth. We stop
  // at 300,000ms (5 minutes) because any latency over that is too high for this
  // benchmark.
  boundary = 100ms;
  increment = 10ms;
  for (int i = 0; i != 150 && boundary <= 300s; ++i) {
    boundaries.push_back(
        std::chrono::duration_cast<dseconds>(boundary).count());
    if (i != 0 && i % 10 == 0) increment *= 2;
    boundary += increment;
  }
  return boundaries;
}

auto make_cpu_histogram_boundaries() {
  // Cloud Monitoring only supports up to 200 buckets per histogram, we have
  // to choose them carefully.
  std::vector<double> boundaries;
  // The units are ns/B, we start with increments of 0.1ns.
  auto boundary = 0.0;
  auto increment = 1.0 / 8.0;
  for (int i = 0; i != 200; ++i) {
    boundaries.push_back(boundary);
    if (i != 0 && i % 32 == 0) increment *= 2;
    boundary += increment;
  }
  return boundaries;
}

auto make_memory_histogram_boundaries() {
  // Cloud Monitoring only supports up to 200 buckets per histogram, we have
  // to choose them carefully.
  std::vector<double> boundaries;
  // We expect the library to use less memory than the transferred size, that is
  // why we stream the data. Use exponentially growing bucket sizes, since we
  // have no better ideas.
  auto boundary = 0.0;
  auto increment = 1.0 / 16.0;
  for (int i = 0; i != 200; ++i) {
    boundaries.push_back(boundary);
    boundary += increment;
    if (i != 0 && i % 16 == 0) increment *= 2;
  }
  return boundaries;
}

void add_histogram_view(opentelemetry::sdk::metrics::MeterProvider& provider,
                        std::string const& name, std::string const& description,
                        std::string const& unit,
                        std::vector<double> boundaries) {
  auto histogram_instrument_selector =
      opentelemetry::sdk::metrics::InstrumentSelectorFactory::Create(
          opentelemetry::sdk::metrics::InstrumentType::kHistogram, name, unit);
  auto histogram_meter_selector =
      opentelemetry::sdk::metrics::MeterSelectorFactory::Create(
          std::string{kAppName}, kVersion, kSchema);

  auto histogram_aggregation_config = std::make_unique<
      opentelemetry::sdk::metrics::HistogramAggregationConfig>();
  histogram_aggregation_config->boundaries_ = std::move(boundaries);
  // Type-erase and convert to shared_ptr.
  auto aggregation_config =
      std::shared_ptr<opentelemetry::sdk::metrics::AggregationConfig>(
          std::move(histogram_aggregation_config));

  auto histogram_view = opentelemetry::sdk::metrics::ViewFactory::Create(
      name, description, unit,
      opentelemetry::sdk::metrics::AggregationType::kHistogram,
      aggregation_config);

  provider.AddView(std::move(histogram_instrument_selector),
                   std::move(histogram_meter_selector),
                   std::move(histogram_view));
}

std::unique_ptr<opentelemetry::metrics::MeterProvider> make_meter_provider(
    google::cloud::Project const& project, std::string const& instance) {
  // We want to configure the latency histogram buckets. Seemingly, this is
  // done rather indirectly in OpenTelemetry. One defines a "selector" that
  // matches the target histogram, and stores the configuration there.
  auto exporter = gc::otel::MakeMonitoringExporter(
      project, gc::monitoring_v3::MakeMetricServiceConnection());

  auto reader_options =
      opentelemetry::sdk::metrics::PeriodicExportingMetricReaderOptions{};
  reader_options.export_interval_millis = std::chrono::seconds(60);
  reader_options.export_timeout_millis = std::chrono::seconds(15);

  std::shared_ptr<opentelemetry::sdk::metrics::MetricReader> reader =
      opentelemetry::sdk::metrics::PeriodicExportingMetricReaderFactory::Create(
          std::move(exporter), reader_options);

  auto provider = opentelemetry::sdk::metrics::MeterProviderFactory::Create(
      std::make_unique<opentelemetry::sdk::metrics::ViewRegistry>(),
      make_resource(instance));
  auto& p = dynamic_cast<opentelemetry::sdk::metrics::MeterProvider&>(
      *provider.get());
  p.AddMetricReader(reader);

  add_histogram_view(p, kLatencyHistogramName, kLatencyDescription,
                     kLatencyHistogramUnit,
                     make_latency_histogram_boundaries());
  add_histogram_view(p, kCpuHistogramName, kCpuDescription, kCpuHistogramUnit,
                     make_cpu_histogram_boundaries());
  add_histogram_view(p, kMemoryHistogramName, kMemoryDescription,
                     kMemoryHistogramUnit, make_memory_histogram_boundaries());

  return provider;
}

boost::program_options::variables_map parse_args(int argc, char* argv[]) {
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
      ("workers", po::value<int>()->default_value(1),
       "the number of worker threads.")  //
      // Open Telemetry Processor options
      ("project-id", po::value<std::string>()->required(),
       "a Google Cloud Project id. The benchmark sends its results to this"
       " project as Cloud Monitoring metrics and Cloud Trace traces.")  //
      ("tracing-rate", po::value<double>()->default_value(kDefaultSampleRate),
       "otel::BasicTracingRateOption value")  //
      ("max-queue-size", po::value<int>()->default_value(2048),
       "set the max queue size for open telemetery")  //
      ;

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

}  // namespace

void* operator new(std::size_t count) {
  allocated_bytes.fetch_add(count);
  return std::malloc(count);
}

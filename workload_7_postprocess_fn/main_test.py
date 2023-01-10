# Copyright 2022 Google LLC
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

from google.cloud import monitoring_v3
from main import current_interval
from main import convert_timeseries_to_dataframe
from main import compare_throughput
from main import power_check
from main import acceptable_effect
from main import get_timeseries_last_n_seconds
from main import apply_compare_throughput
from main import WORKLOADS_LIST
from main import HASH_LIST
from main import __str_bit_to_boolean
from main import __boolean_to_str_bit
from unittest.mock import Mock
import pandas as pd
import numpy as np
import time


def __generate_datapoints(
    mean,
    std,
    api,
    samples_count,
    op="INSERT",
    crc32c_enabled=False,
    md5_enabled=False,
    seed=0,
):
    np.random.seed(seed)
    samples = np.random.normal(mean, std, size=samples_count)
    datapoint_list = []
    for idx in range(0, samples_count):
        new_datapoint = {
            "ApiName": api,
            "Op": op,
            "Crc32cEnabled": crc32c_enabled,
            "MD5Enabled": md5_enabled,
            "TransferSize": samples[idx],
            "ElapsedTimeUs": 1000000,
            "ThroughputKiBs": samples[idx],
            "ThroughputMiBs": samples[idx],
        }
        datapoint_list.append(new_datapoint)
    return datapoint_list


def test_apply_compare_throughput():
    data = __generate_datapoints(5, 2.5, "Xml", 1000)
    data.extend(__generate_datapoints(5, 2.5, "Json", 1000))
    test_df = pd.DataFrame.from_records(data)
    (
        effect,
        result,
        effect_json_less_than_xml,
        json_less_than_xml,
    ) = apply_compare_throughput(test_df)
    assert result == False


def test_convert_timeseries_to_dataframe():
    series_single_datapoint = monitoring_v3.TimeSeries()
    series_single_datapoint.metric.type = (
        "custom.googleapis.com/cloudprober/external/workload_7/throughput"
    )
    series_single_datapoint.metric.labels["api"] = "Xml"
    series_single_datapoint.metric.labels["op"] = "READ[0]"
    series_single_datapoint.metric.labels["transfer_size"] = "1073741824"
    series_single_datapoint.metric.labels["transfer_offset"] = "1024"
    series_single_datapoint.metric.labels["object_size"] = "1073741824"
    series_single_datapoint.metric.labels["elapsed_time_us"] = "1000000"
    series_single_datapoint.metric.labels["crc32c_enabled"] = __boolean_to_str_bit(True)
    series_single_datapoint.metric.labels["md5_enabled"] = __boolean_to_str_bit(False)
    series_single_datapoint.metric.labels["app_buffer_size"] = "1024"
    series_single_datapoint.metric.labels["cpu_time_us"] = "100000"
    series_single_datapoint.metric.labels["peer"] = ""
    series_single_datapoint.metric.labels["bucket_name"] = "bucket_name"
    series_single_datapoint.metric.labels["object_name"] = "object_name"
    series_single_datapoint.metric.labels["generation"] = "1"
    series_single_datapoint.metric.labels["upload_id"] = "upload_id"
    series_single_datapoint.metric.labels["status_code"] = "[OK]"
    series_single_datapoint.points = [
        monitoring_v3.Point(
            {"interval": current_interval(1673372733), "value": {"double_value": 10.0}}
        )
    ]
    actual_df = convert_timeseries_to_dataframe(
        [series_single_datapoint, series_single_datapoint]
    )
    # .from_dict() is only used to validate output of convert_timeseries_to_dataframe
    expected_df = pd.DataFrame.from_dict(
        {
            "Timestamp": {
                0: "2023-01-10 17:45:33+00:00",
                1: "2023-01-10 17:45:33+00:00",
            },
            "Library": {0: "", 1: ""},
            "ApiName": {0: "Xml", 1: "Xml"},
            "Op": {0: "READ[0]", 1: "READ[0]"},
            "ObjectSize": {0: 1073741824, 1: 1073741824},
            "Crc32cEnabled": {0: True, 1: True},
            "MD5Enabled": {0: False, 1: False},
            "ElapsedTimeUs": {0: 1000000, 1: 1000000},
            "TransferSize": {0: 1073741824, 1: 1073741824},
            "TransferOffset": {0: 1024, 1: 1024},
            "AppBufferSize": {0: 1024, 1: 1024},
            "CpuTimeUs": {0: 100000, 1: 100000},
            "Peer": {0: "", 1: ""},
            "BucketName": {0: "bucket_name", 1: "bucket_name"},
            "ObjectName": {0: "object_name", 1: "object_name"},
            "Generation": {0: "1", 1: "1"},
            "UploadId": {0: "upload_id", 1: "upload_id"},
            "StatusCode": {0: "[OK]", 1: "[OK]"},
            "ThroughputMiBs": {0: 1024.0, 1: 1024.0},
            "ThroughputKiBs": {0: 1048576.0, 1: 1048576.0},
        }
    )
    assert actual_df.equals(expected_df) == True


def test_compare_throughput_null_hypothesis_distributions():
    # Generate a random with different mean distributions
    # H_0: They're equal distributions
    # ---> H_1: They're not identical distributions
    data = __generate_datapoints(5, 2.5, "Xml", 1000)
    data.extend(__generate_datapoints(5, 2.5, "Json", 1000))
    dataframe = pd.DataFrame.from_records(data)
    (
        effect,
        result,
        effect_json_less_than_xml,
        json_less_than_xml,
    ) = compare_throughput(dataframe)
    assert result == False


def test_compare_throughput_two_sided_hypothesis_distributions():
    # Generate a random with same mean distributions
    # ---> H_0: They're equal distributions
    # H_1: They're not identical distributions
    data = __generate_datapoints(5, 2.5, "Xml", 1000)
    data.extend(__generate_datapoints(100, 2.5, "Json", 1000))
    dataframe = pd.DataFrame.from_records(data)
    (
        effect,
        result,
        effect_json_less_than_xml,
        json_less_than_xml,
    ) = compare_throughput(dataframe)
    assert result == True


def test_power_check_enough_samples():
    # Generate a random with many datapoints
    data = __generate_datapoints(5, 2.5, "Xml", 80000)
    data.extend(__generate_datapoints(5, 2.5, "Json", 80000))
    dataframe = pd.DataFrame.from_records(data)
    actual_results = power_check(dataframe, acceptable_effect)
    # The following expected results are generated first through
    # actual_results and verified to have the structure expected output.
    # In the future if we want to update this structure; we will want to
    # print(actual_results) then inline them here; we don't want to get exact
    # values as it could be flaky.

    assert actual_results["sample_count"] == "160000"
    assert actual_results["enough_samples"] == "True"
    assert actual_results["needed_samples"] != ""
    assert actual_results["effect"] != ""
    assert actual_results["std_xml"] != ""
    assert actual_results["std_json"] != ""
    assert actual_results["mean_xml"] != ""
    assert actual_results["mean_json"] != ""


def test_current_interval():
    now = time.time()
    seconds = int(now)
    nanos = int((now - seconds) * 10**9)
    expected_interval = monitoring_v3.TimeInterval(
        {
            "end_time": {"seconds": seconds, "nanos": nanos},
            "start_time": {"seconds": seconds, "nanos": nanos},
        }
    )
    actual_interval = current_interval(now)
    assert actual_interval == expected_interval


def test_get_timeseries_last_n_seconds():
    mock_client = Mock()
    now = time.time()
    series = get_timeseries_last_n_seconds(
        mock_client,
        "test-project-id",
        "custom.googleapis.com/metric",
        lookback_seconds=86400,
        now=now,
    )
    # Verify that method to call list API is made
    mock_client.list_time_series.assert_called_once()

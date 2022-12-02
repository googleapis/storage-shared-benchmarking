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
from main import compare_mibs
from main import power_check
from main import write_stat_result
from main import get_timeseries_last_24h
from main import apply_compare_mibs
from main import WORKLOADS_LIST
from main import HASH_TUPLE_LIST
from unittest.mock import Mock
import pandas as pd
import numpy as np
import time


def __generate_datapoints(mean, std, api, samples_count):
    # Generate samples for WRITE, READ[0], READ[1], READ[2]
    # Predictable random numbers: we want to verify expected output and expected cases possible.
    np.random.seed(0)
    samples = np.random.normal(
        mean, std, size=(samples_count * len(WORKLOADS_LIST) * len(HASH_TUPLE_LIST))
    )
    datapoint_list = []
    idx = 0
    for _ in range(0, samples_count):
        for op in WORKLOADS_LIST:
            for hash_tuple in HASH_TUPLE_LIST:
                new_datapoint = {
                    "ApiName": api,
                    "Op": op,
                    "Crc32cEnabled": hash_tuple[0],
                    "MD5Enabled": hash_tuple[1],
                    "MiBs": samples[idx],
                }
                idx += 1
                datapoint_list.append(new_datapoint)
    return datapoint_list


def test_apply_compare_mibs():
    data = __generate_datapoints(5, 2.5, "Xml", 1000)
    data.extend(__generate_datapoints(5, 2.5, "Json", 1000))
    test_df = pd.DataFrame.from_records(data)
    results = apply_compare_mibs(test_df)
    for op in WORKLOADS_LIST:
        for hash_tuple in HASH_TUPLE_LIST:
            assert results.loc[(op, hash_tuple[0], hash_tuple[1])] == False


def test_convert_timeseries_to_dataframe():
    series_single_datapoint = monitoring_v3.TimeSeries()
    series_single_datapoint.metric.type = (
        "custom.googleapis.com/cloudprober/external/workload_7/throughput"
    )
    series_single_datapoint.metric.labels["api"] = "Xml"
    series_single_datapoint.metric.labels["op"] = "READ[0]"
    series_single_datapoint.metric.labels["crc32c_enabled"] = "1"
    series_single_datapoint.metric.labels["md5_enabled"] = "0"
    series_single_datapoint.points = [
        monitoring_v3.Point(
            {"interval": current_interval(), "value": {"double_value": 10.0}}
        )
    ]
    actual_df = convert_timeseries_to_dataframe([series_single_datapoint])
    expected_df = pd.DataFrame.from_records(
        [
            {
                "ApiName": "Xml",
                "Op": "READ[0]",
                "Crc32cEnabled": "1",
                "MD5Enabled": "0",
                "MiBs": 10.0,
            }
        ]
    )
    assert actual_df.equals(expected_df) == True


def test_compare_mibs_null_hypothesis_distributions():
    # Generate a random with different mean distributions
    # H_0: They're equal distributions
    # ---> H_1: They're not identical distributions
    data = __generate_datapoints(5, 2.5, "Xml", 1000)
    data.extend(__generate_datapoints(5, 2.5, "Json", 1000))
    dataframe = pd.DataFrame.from_records(data)
    result = compare_mibs(dataframe)
    assert result == False


def test_compare_mibs_two_sided_hypothesis_distributions():
    # Generate a random with same mean distributions
    # ---> H_0: They're equal distributions
    # H_1: They're not identical distributions
    data = __generate_datapoints(5, 2.5, "Xml", 1000)
    data.extend(__generate_datapoints(100, 2.5, "Json", 1000))
    dataframe = pd.DataFrame.from_records(data)
    result = compare_mibs(dataframe)
    assert result == True


def test_power_check_enough_samples():
    # Generate a random with many datapoints
    data = __generate_datapoints(5, 2.5, "Xml", 1000)
    data.extend(__generate_datapoints(5, 2.5, "Json", 1000))
    dataframe = pd.DataFrame.from_records(data)
    actual_results = power_check(dataframe)
    # The following expected results are generated first through
    # actual_results and verified to have the structure expected output.
    # In the future if we want to update this structure; we will want to
    # print(actual_results) then inline them here.
    expected_results = {
        ("WRITE", "1", "1"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("WRITE", "0", "1"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("WRITE", "1", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("WRITE", "0", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("INSERT", "1", "1"): {
            "needed_samples": "8",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("INSERT", "0", "1"): {
            "needed_samples": "10",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("INSERT", "1", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("INSERT", "0", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[0]", "1", "1"): {
            "needed_samples": "10",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[0]", "0", "1"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[0]", "1", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[0]", "0", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[1]", "1", "1"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[1]", "0", "1"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[1]", "1", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[1]", "0", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[2]", "1", "1"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[2]", "0", "1"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[2]", "1", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
        ("READ[2]", "0", "0"): {
            "needed_samples": "9",
            "sample_count": "2000",
            "enough_samples": "True",
        },
    }
    assert actual_results == expected_results


def test_current_interval():
    now = time.time()
    seconds = int(now)
    nanos = int((now - seconds) * 10**9)
    expected_interval = monitoring_v3.TimeInterval(
        {"end_time": {"seconds": seconds, "nanos": nanos}}
    )
    actual_interval = current_interval(now)
    assert actual_interval == expected_interval


def test_write_stat_result():
    mock_client = Mock()
    data = __generate_datapoints(5, 2.5, "Xml", 1000)
    data.extend(__generate_datapoints(5, 2.5, "Json", 1000))
    dataframe = pd.DataFrame.from_records(data)
    results = apply_compare_mibs(dataframe)
    power_info = power_check(dataframe)
    write_stat_result(mock_client, "test-project-id", results, power_info)
    # Verify that data points were written one per workload
    assert mock_client.create_time_series.call_count == (
        len(WORKLOADS_LIST) * len(HASH_TUPLE_LIST)
    )


def test_get_timeseries_last_24h():
    mock_client = Mock()
    now = time.time()
    series = get_timeseries_last_24h(
        mock_client, "test-project-id", "custom.googleapis.com/metric", now
    )
    # Verify that method to call list API is made
    mock_client.list_time_series.assert_called_once

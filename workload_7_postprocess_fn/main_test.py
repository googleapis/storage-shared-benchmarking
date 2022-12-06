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
from main import get_timeseries_last_n_seconds
from main import apply_compare_mibs
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
            "MiBs": samples[idx],
        }
        datapoint_list.append(new_datapoint)
    return datapoint_list


def test_apply_compare_mibs():
    data = __generate_datapoints(5, 2.5, "Xml", 1000)
    data.extend(__generate_datapoints(5, 2.5, "Json", 1000))
    test_df = pd.DataFrame.from_records(data)
    result = apply_compare_mibs(test_df)
    assert result.loc[("INSERT", False, False)] == False


def test_convert_timeseries_to_dataframe():
    series_single_datapoint = monitoring_v3.TimeSeries()
    series_single_datapoint.metric.type = (
        "custom.googleapis.com/cloudprober/external/workload_7/throughput"
    )
    series_single_datapoint.metric.labels["api"] = "Xml"
    series_single_datapoint.metric.labels["op"] = "READ[0]"
    series_single_datapoint.metric.labels["transfer_size"] = "1024"
    series_single_datapoint.metric.labels["object_size"] = "1024"
    series_single_datapoint.metric.labels["crc32c_enabled"] = __boolean_to_str_bit(True)
    series_single_datapoint.metric.labels["md5_enabled"] = __boolean_to_str_bit(False)
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
                "Crc32cEnabled": True,
                "MD5Enabled": False,
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
        "needed_samples": "9",
        "sample_count": "2000",
        "enough_samples": "True",
    }
    assert actual_results == expected_results


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


def test_write_stat_result():
    mock_client = Mock()
    op = "INSERT"
    crc32c_disabled = False
    md5_disabled = False
    data = __generate_datapoints(5, 2.5, "Xml", 1000, op, crc32c_disabled, md5_disabled)
    data.extend(
        __generate_datapoints(5, 2.5, "Json", 1000, op, crc32c_disabled, md5_disabled)
    )
    dataframe = pd.DataFrame.from_records(data)
    result = apply_compare_mibs(dataframe)
    power_info = power_check(dataframe)
    write_stat_result(
        mock_client,
        "test-project-id",
        op,
        crc32c_disabled,
        md5_disabled,
        result,
        power_info,
    )
    mock_client.create_time_series.assert_called_once()


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

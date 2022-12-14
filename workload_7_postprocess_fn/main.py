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

import functions_framework
from google.cloud import monitoring_v3
import statsmodels.stats.power as pwr
import numpy as np
import pandas as pd
import time
import os
import scipy as sp


# Subworkloads:
# INSERT using InsertObject (Multipart Upload)
# WRITE using WriteObject  (Resumable Upload)
# READ used by both XML and JSON
# RANGE special label to identify range reads in both XML and JSON
WORKLOADS_LIST = [
    "WRITE",
    "INSERT",
    "READ[0]",
    "READ[1]",
    "READ[2]",
    "RANGE[0]",
    "RANGE[1]",
    "RANGE[2]",
]
HASH_LIST = [{"crc32c": True, "md5": False}, {"crc32c": False, "md5": False}]
DAY_IN_SECONDS = 86400


def compare_mibs(df, a="Json", b="Xml", alpha=0.001):
    # alpha=0.001 more regirous than commonly used 0.05
    # Notes: Mannwhitneyu is able to apply the test across each subworkload
    # H_0: They're equal distributions
    # H_1: They're not equal distributions
    _, p = sp.stats.mannwhitneyu(
        df[df.ApiName == a].MiBs, df[df.ApiName == b].MiBs, alternative="two-sided"
    )
    # if p < alpha: H_1
    # else: H_0
    return p < alpha


def power_check(df):
    std = df.groupby(["ApiName"], group_keys=True).MiBs.apply(np.std).max()
    effect = 5 / std
    p = pwr.TTestIndPower()
    needed_samples = round(p.solve_power(effect_size=effect, alpha=0.01, power=0.90))
    sample_count = len(df.index)
    enough_samples = sample_count >= needed_samples
    power_results = {
        "needed_samples": f"{needed_samples}",
        "sample_count": f"{sample_count}",
        "enough_samples": f"{enough_samples}",
    }
    return power_results


def get_timeseries_last_n_seconds(
    client, project_name, metric, lookback_seconds, op_filter=None, now=None
):
    if now is None:
        now = time.time()
    project_name_with_path = f"projects/{project_name}"
    interval = monitoring_v3.TimeInterval()
    seconds = int(now)
    nanos = int((now - seconds) * 10**9)
    # Look back at yesterdays worth of data
    interval = monitoring_v3.TimeInterval(
        {
            "end_time": {"seconds": seconds, "nanos": nanos},
            "start_time": {"seconds": (seconds - lookback_seconds), "nanos": nanos},
        }
    )
    request = {
        "name": project_name_with_path,
        "filter": f'metric.type = "{metric}"',
        "interval": interval,
        "view": monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
    }
    if op_filter is not None:
        request["filter"] += f' AND metric.labels.op = starts_with("{op_filter}")'
    results = client.list_time_series(request)
    return results


def current_interval(now=None):
    if now is None:
        now = time.time()
    seconds = int(now)
    nanos = int((now - seconds) * 10**9)
    interval = monitoring_v3.TimeInterval(
        {
            "end_time": {"seconds": seconds, "nanos": nanos},
            "start_time": {"seconds": seconds, "nanos": nanos},
        }
    )
    return interval


def __str_bit_to_boolean(str_bit):
    if str_bit == "1":
        return True
    return False


def __boolean_to_str_bit(b):
    if b:
        return "1"
    return "0"


def convert_timeseries_to_dataframe(timeseries):
    processed_data = []
    for datapoint in timeseries:
        labels = datapoint.metric.labels
        op = labels["op"]
        if int(labels["transfer_size"]) < int(labels["object_size"]):
            op = op.replace("READ", "RANGE")
        converted_datapoint = {
            "ApiName": labels["api"],
            "Op": op,
            "Crc32cEnabled": __str_bit_to_boolean(labels["crc32c_enabled"]),
            "MD5Enabled": __str_bit_to_boolean(labels["md5_enabled"]),
            "MiBs": datapoint.points[0].value.double_value,
        }
        processed_data.append(converted_datapoint)
    df = pd.DataFrame.from_records(processed_data)
    return df


def write_stat_result(
    client,
    project_name,
    op,
    crc32c_enabled,
    md5_enabled,
    result,
    power_info,
    interval=None,
):
    if interval is None:
        interval = current_interval()
    project_name_with_path = f"projects/{project_name}"
    series = monitoring_v3.TimeSeries()
    series.metric.type = (
        "custom.googleapis.com/cloudprober/external/workload_7/stat_result"
    )
    series.metric.labels["Op"] = op
    series.metric.labels["crc32c_enabled"] = __boolean_to_str_bit(crc32c_enabled)
    series.metric.labels["md5_enabled"] = __boolean_to_str_bit(md5_enabled)
    series.metric.labels["neededSamples"] = power_info["needed_samples"]
    series.metric.labels["sampleCount"] = power_info["sample_count"]
    series.metric.labels["enoughSamples"] = power_info["enough_samples"]
    point = monitoring_v3.Point(
        {
            "interval": interval,
            "value": {"bool_value": result.loc[(op, crc32c_enabled, md5_enabled)]},
        }
    )
    series.points = [point]
    client.create_time_series(name=project_name_with_path, time_series=[series])


def apply_compare_mibs(dataframe):
    return dataframe.groupby(["Op", "Crc32cEnabled", "MD5Enabled"]).apply(compare_mibs)


@functions_framework.http
def run_workload_7_post_processing(_):
    # Use project of deployed GCF
    project_name = os.environ["GCP_PROJECT"]
    monitoring_client = monitoring_v3.MetricServiceClient()
    timeseries_data = []
    for api in ["Xml", "Json"]:
        for upload_type in ["InsertObject", "WriteObject"]:
            for size in [
                8 * 1024,
                256 * 1024,
                1024 * 1024,
                1024 * 1024 * 16,
                1024 * 1024 * 128,
                1024 * 1024 * 1024,
            ]:
                timeseries_data.extend(
                    get_timeseries_last_n_seconds(
                        monitoring_client,
                        project_name,
                        f"custom.googleapis.com/cloudprober/external/workload_7_{api}_{size}_{upload_type}/throughput",
                        DAY_IN_SECONDS,  # 24 hours in seconds
                    )
                )
            for range_size in [
                1024 * 16,
                1024 * 1024 * 2,
                1024 * 1024 * 16,
            ]:
                timeseries_data.extend(
                    get_timeseries_last_n_seconds(
                        monitoring_client,
                        project_name,
                        f"custom.googleapis.com/cloudprober/external/workload_7_range_{api}_{range_size}_{upload_type}/throughput",
                        DAY_IN_SECONDS * 7,  # 7 days in seconds
                        "READ",  # Ignore Writes
                    )
                )
    full_dataframe = convert_timeseries_to_dataframe(timeseries_data)
    interval_to_write = current_interval()
    for op in WORKLOADS_LIST:
        for hash_values in HASH_LIST:
            filtered_df = full_dataframe[
                (full_dataframe.Op == op)
                & (full_dataframe.Crc32cEnabled == hash_values["crc32c"])
                & (full_dataframe.MD5Enabled == hash_values["md5"])
            ]
            result = apply_compare_mibs(filtered_df)
            power_info = power_check(filtered_df)
            write_stat_result(
                monitoring_client,
                project_name,
                op,
                hash_values["crc32c"],
                hash_values["md5"],
                result,
                power_info,
                interval_to_write,
            )
    return "ok"


if __name__ == "__main__":
    run_workload_7_post_processing(None)

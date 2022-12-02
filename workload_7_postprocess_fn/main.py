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
# READ method doesn't matter between XML / JSON
WORKLOADS_LIST = [
    "WRITE",
    "INSERT",
    "READ[0]",
    "READ[1]",
    "READ[2]",
]
HASH_TUPLE_LIST = [("1", "1"), ("0", "1"), ("1", "0"), ("0", "0")]


def compare_mibs(df, a="Json", b="Xml", alpha=0.001):
    # alpha=0.001 selected by coryan@ as more regirous than commonly used 0.05
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
    power_results = {}
    # Notes: We need to filter by subworkload before running power analysis
    for op in WORKLOADS_LIST:
        for hash_tuple in HASH_TUPLE_LIST:
            filtered_df = df[
                (df.Op == op)
                & (df.Crc32cEnabled == hash_tuple[0])
                & (df.MD5Enabled == hash_tuple[1])
            ]
            std = (
                filtered_df.groupby(["ApiName"], group_keys=True)
                .MiBs.apply(np.std)
                .max()
            )
            effect = 5 / std
            p = pwr.TTestIndPower()
            needed_samples = round(
                p.solve_power(effect_size=effect, alpha=0.01, power=0.90)
            )
            sample_count = len(filtered_df.index)
            enough_samples = sample_count >= needed_samples
            idx = (op, hash_tuple[0], hash_tuple[1])
            power_results[idx] = {
                "needed_samples": f"{needed_samples}",
                "sample_count": f"{sample_count}",
                "enough_samples": f"{enough_samples}",
            }
    return power_results


def get_timeseries_last_24h(client, project_name, metric, now=None):
    project_name_with_path = f"projects/{project_name}"
    interval = monitoring_v3.TimeInterval()
    if now is None:
        now = time.time()
    seconds = int(now)
    nanos = int((now - seconds) * 10**9)
    # Look back at yesterdays worth of data
    interval = monitoring_v3.TimeInterval(
        {
            "end_time": {"seconds": seconds, "nanos": nanos},
            "start_time": {"seconds": (seconds - 86400), "nanos": nanos},
        }
    )
    results = client.list_time_series(
        request={
            "name": project_name_with_path,
            "filter": f'metric.type = "{metric}"',
            "interval": interval,
            "view": monitoring_v3.ListTimeSeriesRequest.TimeSeriesView.FULL,
        }
    )
    return results


def current_interval(now=None):
    if now is None:
        now = time.time()
    seconds = int(now)
    nanos = int((now - seconds) * 10**9)
    interval = monitoring_v3.TimeInterval(
        {"end_time": {"seconds": seconds, "nanos": nanos}}
    )
    return interval


def convert_timeseries_to_dataframe(timeseries):
    processed_data = []
    for datapoint in timeseries:
        processed_data.append(
            {
                "ApiName": datapoint.metric.labels["api"],
                "Op": datapoint.metric.labels["op"],
                "Crc32cEnabled": datapoint.metric.labels["crc32c_enabled"],
                "MD5Enabled": datapoint.metric.labels["md5_enabled"],
                "MiBs": datapoint.points[0].value.double_value,
            }
        )
    df = pd.DataFrame.from_records(processed_data)
    return df


def write_stat_result(client, project_name, results, power_info):
    project_name_with_path = f"projects/{project_name}"
    series = monitoring_v3.TimeSeries()
    series.metric.type = (
        "custom.googleapis.com/cloudprober/external/workload_7/stat_result"
    )
    for op in WORKLOADS_LIST:
        for hash_tuple in HASH_TUPLE_LIST:
            series.metric.labels["Op"] = op
            series.metric.labels["crc32c_enabled"] = hash_tuple[0]
            series.metric.labels["md5_enabled"] = hash_tuple[1]
            idx = (op, hash_tuple[0], hash_tuple[1])
            series.metric.labels["neededSamples"] = power_info[idx]["needed_samples"]
            series.metric.labels["sampleCount"] = power_info[idx]["sample_count"]
            series.metric.labels["enoughSamples"] = power_info[idx]["enough_samples"]
            point = monitoring_v3.Point(
                {
                    "interval": current_interval(),
                    "value": {"bool_value": results.loc[idx]},
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
    raw_timeseries_data = []
    for api in ["XML", "JSON"]:
        for upload_type in ["InsertObject", "WriteObject"]:
            for size in [
                8 * 1024,
                256 * 1024,
                1024 * 1024,
                1024 * 1024 * 16,
                1024 * 1024 * 128,
                1024 * 1024 * 1024,
            ]:
                raw_timeseries_data.extend(
                    get_timeseries_last_24h(
                        monitoring_client,
                        project_name,
                        f"custom.googleapis.com/cloudprober/external/workload_7_{api}_{size}_{upload_type}/throughput",
                    )
                )
    df = convert_timeseries_to_dataframe(raw_timeseries_data)
    result = apply_compare_mibs(df)
    power_info = power_check(df)
    write_stat_result(client, project_name, result, power_info)
    return "ok"

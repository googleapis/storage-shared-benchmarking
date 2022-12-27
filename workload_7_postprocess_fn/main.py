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


def compare_throughput(df, a="Json", b="Xml", alpha=0.001):
    # alpha=0.001 more regirous than commonly used 0.05
    # Notes: Mannwhitneyu is able to apply the test across each subworkload
    # H_0: They're equal distributions
    # H_1: They're not equal distributions
    statistic, p = None, None
    s_less, p_less = None, None
    if df.ObjectSize.max() < 1024 * 1024:
        group_a = df[df.ApiName == a].ThroughputKiBs
        group_b = df[df.ApiName == b].ThroughputKiBs
        statistic, p = sp.stats.mannwhitneyu(
            group_a,
            group_b,
            alternative="two-sided",
        )
        s_less, p_less = sp.stats.mannwhitneyu(
            group_a,
            group_b,
            alternative="less",
        )
    else:
        group_a = df[df.ApiName == a].ThroughputMiBs
        group_b = df[df.ApiName == b].ThroughputMiBs
        statistic, p = sp.stats.mannwhitneyu(
            group_a,
            group_b,
            alternative="two-sided",
        )
        s_less, p_less = sp.stats.mannwhitneyu(
            group_a,
            group_b,
            alternative="less",
        )
    # https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test#Rank-biserial_correlation
    rank_biserial_correlation = (
        (2 * statistic)
        / (len(df[df.ApiName == a].index) * len(df[df.ApiName == b].index))
    ) - 1
    rank_biserial_correlation_less = (
        (2 * s_less) / (len(df[df.ApiName == a].index) * len(df[df.ApiName == b].index))
    ) - 1
    # if p < alpha: H_1
    # else: H_0
    return (
        rank_biserial_correlation,
        p < alpha,
        rank_biserial_correlation_less,
        p_less < alpha,
    )


def apply_compare_throughput(dataframe):
    result = dataframe.groupby(
        ["Op", "ObjectSize", "Crc32cEnabled", "MD5Enabled"], group_keys=True
    ).apply(compare_throughput)
    return result[0][0], result[0][1], result[0][2], result[0][3]


def acceptable_effect(series):
    std = series.apply(np.std).max()
    mean = series.apply(np.mean).max()
    # Based on Cohens D standardized effect
    # to get % of effect based on input max mean and max std that
    # is used to determined the effect we want to find when
    # running Mann-Whitney U Test; We say we only care about effect greater
    # than or equal X% of the mean throughput.
    effect = (mean * 0.01) / std
    return effect


def power_check(df, effect_fn):
    series = None
    if df.ObjectSize.max() < 1024 * 1024:
        series = df.groupby(["ApiName"], group_keys=True).ThroughputKiBs
    else:
        series = df.groupby(["ApiName"], group_keys=True).ThroughputMiBs
    mean_both = series.apply(np.mean)
    std_both = series.apply(np.std)
    std = std_both.max()
    effect = effect_fn(series)
    p = pwr.TTestIndPower()
    needed_samples = p.solve_power(effect_size=effect, alpha=0.01, power=0.90)
    # increase samples needed due to findings in https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test#Comparison_to_Student%27s_t-test
    needed_samples = needed_samples * 1.05
    sample_count = len(df.index)
    enough_samples = sample_count >= needed_samples
    power_results = {
        "needed_samples": f"{round(needed_samples, -1)}",
        "sample_count": f"{sample_count}",
        "enough_samples": f"{enough_samples}",
        "effect": f"{effect}",
        "std_xml": f"{std_both.Xml}",
        "std_json": f"{std_both.Json}",
        "mean_xml": f"{mean_both.Xml}",
        "mean_json": f"{mean_both.Json}",
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
        point = datapoint.points[0]
        op = labels["op"]
        transfer_size = int(labels["transfer_size"])
        elapsed_time_us = int(labels["elapsed_time_us"])
        us_in_seconds = 1_000_000
        throughput_mibs = (transfer_size / 1024 / 1024) / (elapsed_time_us / us_in_seconds)
        throughput_kibs = (transfer_size / 1024) / (elapsed_time_us / us_in_seconds)
        if int(labels["transfer_size"]) < int(labels["object_size"]):
            op = op.replace("READ", "RANGE")
        converted_datapoint = {
            "Timestamp": f"{point.interval.end_time}",
            "Library": labels["library"],
            "ApiName": labels["api"],
            "Op": op,
            "ObjectSize": transfer_size,
            "Crc32cEnabled": __str_bit_to_boolean(labels["crc32c_enabled"]),
            "MD5Enabled": __str_bit_to_boolean(labels["md5_enabled"]),
            "ElapsedTimeUs": elapsed_time_us,
            "TransferSize": transfer_size,
            "TransferOffset": int(labels["transfer_offset"]),
            "AppBufferSize": int(labels["app_buffer_size"]),
            "CpuTimeUs": int(labels["cpu_time_us"]),
            "Peer": labels["peer"],
            "BucketName": labels["bucket_name"],
            "ObjectName": labels["object_name"],
            "Generation": labels["generation"],
            "UploadId": labels["upload_id"],
            "StatusCode": labels["status_code"],
            "ThroughputMiBs": throughput_mibs,
            "ThroughputKiBs": throughput_kibs,
        }
        processed_data.append(converted_datapoint)
    df = pd.DataFrame.from_records(processed_data)
    return df


def write_stat_result(
    client,
    project_name,
    op,
    object_size,
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
    series.metric.labels["op"] = op
    series.metric.labels["object_size"] = f"{object_size}"
    series.metric.labels["crc32c_enabled"] = __boolean_to_str_bit(crc32c_enabled)
    series.metric.labels["md5_enabled"] = __boolean_to_str_bit(md5_enabled)
    series.metric.labels["needed_samples"] = power_info["needed_samples"]
    series.metric.labels["sample_count"] = power_info["sample_count"]
    series.metric.labels["enough_samples"] = power_info["enough_samples"]
    point = monitoring_v3.Point(
        {
            "interval": interval,
            "value": {
                "bool_value": result.loc[(op, object_size, crc32c_enabled, md5_enabled)]
            },
        }
    )
    series.points = [point]
    client.create_time_series(name=project_name_with_path, time_series=[series])


def print_header():
    print(
        "op,object_size,needed_samples,sample_count,enough_samples,effect,std_xml,std_json,mean_xml,mean_json,distribution_different,json_less_than_xml,effect_json_less_than_xml,winning_api,winning_api_without_power"
    )


def winning_api_result(object_size, two_tailed, json_less_than_xml, enough_samples):
  lesser_than = "XML"
  greater_than = "JSON"
  winning_api = None
  if not two_tailed:
    winning_api = "Identical"
  elif two_tailed and json_less_than_xml:
    winning_api = lesser_than
  elif two_tailed and not json_less_than_xml:
    winning_api = greater_than
  if enough_samples == "False":
    return "Need more samples", winning_api
  else:
    return winning_api, winning_api


@functions_framework.http
def run_workload_7_post_processing(_):
    # Use project of deployed GCF
    project_name = os.environ["GCP_PROJECT"]
    monitoring_client = monitoring_v3.MetricServiceClient()
    interval_to_write = current_interval()
    timeseries_data = []
    for api in ["Xml", "Json"]:
        for upload_type in [
          "InsertObject",
          "WriteObject"
          ]:
            for size in [
                8 * 1024,
                256 * 1024,
                1024 * 1024,
                1024 * 1024 * 16,
                1024 * 1024 * 128,
                1024 * 1024 * 1024,
            ]:
                timeseries_data.extend(get_timeseries_last_n_seconds(
                        monitoring_client,
                        project_name,
                        f"custom.googleapis.com/cloudprober/external/workload_7_{api}_{size}_{upload_type}/throughput",
                        DAY_IN_SECONDS * 60
                    ))
            for range_size in [
                1024 * 16,
                1024 * 1024 * 2,
                1024 * 1024 * 16,
            ]:
                timeseries_data.extend(get_timeseries_last_n_seconds(
                        monitoring_client,
                        project_name,
                        f"custom.googleapis.com/cloudprober/external/workload_7_range_{api}_{range_size}_{upload_type}/throughput",
                        DAY_IN_SECONDS * 60,
                        "READ",  # Ignore Writes
                        # now=1671178525
                ))
    full_dataframe = convert_timeseries_to_dataframe(timeseries_data)
    full_dataframe.to_csv("out_last-60-with-timestamp.csv")
    full_dataframe = pd.read_csv("out_last-60-with-timestamp.csv")
    print(full_dataframe.Timestamp.describe())
    print_header()
    for object_size, effect_fn in [
        (8 * 1024, acceptable_effect),
        (256 * 1024, acceptable_effect),
        (1024 * 1024, acceptable_effect),
        (1024 * 1024 * 16, acceptable_effect),
        (1024 * 1024 * 128, acceptable_effect),
        (1024 * 1024 * 1024, acceptable_effect),
    ]:
        for op in [
            "WRITE",
            "INSERT",
            "READ[2]",
        ]:
            try:
                df = full_dataframe[
                    (full_dataframe.Op == op)
                    & (full_dataframe.ObjectSize == object_size)
                    & (full_dataframe.StatusCode == "OK")
                ]
                (
                    effect,
                    result,
                    effect_json_less_than_xml,
                    json_less_than_xml,
                ) = apply_compare_throughput(df)
                power_info = power_check(df, effect_fn)
                (winning_api, winning_api_without_power) = winning_api_result(object_size, result, json_less_than_xml, power_info["enough_samples"])
                if not result:
                    json_less_than_xml = "N/A"
                    effect_json_less_than_xml = "N/A"
                print(
                    f"{op},{object_size},{power_info['needed_samples']},{power_info['sample_count']},{power_info['enough_samples']},{power_info['effect']},{power_info['std_xml']},{power_info['std_json']},{power_info['mean_xml']},{power_info['mean_json']},{result},{json_less_than_xml},{effect_json_less_than_xml},{winning_api},{winning_api_without_power}"
                )
            except Exception as e:
                print(e)
                print(f"{op},{object_size},,,,,,,,,True")
    for object_size, effect_fn in [
        (1024 * 16, acceptable_effect),
        (1024 * 1024 * 2, acceptable_effect),
        (1024 * 1024 * 16, acceptable_effect),
    ]:
        for op in [
            "RANGE[2]",
        ]:
            try:
                df = full_dataframe[
                    (full_dataframe.Op == op)
                    & (full_dataframe.ObjectSize == object_size)
                    & (full_dataframe.StatusCode == "OK")
                ]
                (
                    effect,
                    result,
                    effect_json_less_than_xml,
                    json_less_than_xml,
                ) = apply_compare_throughput(df)
                power_info = power_check(df, effect_fn)
                winning_api, winning_api_without_power = winning_api_result(object_size, result, json_less_than_xml, power_info["enough_samples"])
                if not result:
                  json_less_than_xml = "N/A"
                  effect_json_less_than_xml = "N/A"
                print(
                    f"{op},{object_size},{power_info['needed_samples']},{power_info['sample_count']},{power_info['enough_samples']},{power_info['effect']},{power_info['std_xml']},{power_info['std_json']},{power_info['mean_xml']},{power_info['mean_json']},{result},{json_less_than_xml},{effect_json_less_than_xml},{winning_api},{winning_api_without_power}"
                )
            except Exception as e:
                print(e)
                print(f"{op},{object_size},,,,,,,,,True")
    return "ok"


if __name__ == "__main__":
    run_workload_7_post_processing(None)

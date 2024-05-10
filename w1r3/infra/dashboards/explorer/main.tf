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

resource "google_monitoring_dashboard" "ratios" {
  lifecycle {
    prevent_destroy = true
    ignore_changes = [dashboard_json]
  }
  dashboard_json = <<EOF
{
  "displayName": "W1R3 - Explorer",
  "dashboardFilters": [
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_deployment",
      "stringValue": "",
      "templateVariable": ""
    },
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_transport",
      "stringValue": "",
      "templateVariable": ""
    },
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_language",
      "stringValue": "",
      "templateVariable": ""
    },
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_op",
      "stringValue": "",
      "templateVariable": ""
    }
  ],
  "mosaicLayout": {
    "columns": 48,
    "tiles": [
      {
        "width": 16,
        "height": 17,
        "widget": {
          "title": "w1r3-latency for 100KB objects - [50TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "minAlignmentPeriod": "300s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                      "groupByFields": [],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_object_size\"=\"100000\""
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "xPos": 16,
        "width": 16,
        "height": 17,
        "widget": {
          "title": "w1r3-latency for 2MiB objects - [50TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "minAlignmentPeriod": "300s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                      "groupByFields": [],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_object_size\"=\"2097152\""
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "xPos": 32,
        "width": 16,
        "height": 17,
        "widget": {
          "title": "w1r3-latency for 100MB objects - [50TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "minAlignmentPeriod": "300s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                      "groupByFields": [],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_object_size\"=\"100000000\""
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "yPos": 17,
        "width": 16,
        "height": 17,
        "widget": {
          "title": "w1r3-latency for 100KB objects - [95TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "minAlignmentPeriod": "300s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_95",
                      "groupByFields": [],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_object_size\"=\"100000\""
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "xPos": 16,
        "yPos": 17,
        "width": 16,
        "height": 17,
        "widget": {
          "title": "w1r3-latency for 2MiB objects - [95TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "minAlignmentPeriod": "300s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_95",
                      "groupByFields": [],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_object_size\"=\"2097152\""
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "xPos": 32,
        "yPos": 17,
        "width": 16,
        "height": 17,
        "widget": {
          "title": "w1r3-latency for 100MB objects - [95TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "minAlignmentPeriod": "300s",
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "300s",
                      "crossSeriesReducer": "REDUCE_PERCENTILE_95",
                      "groupByFields": [],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_object_size\"=\"100000000\""
                  }
                }
              }
            ],
            "thresholds": [],
            "timeshiftDuration": "0s",
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            }
          }
        }
      },
      {
        "xPos": 16,
        "yPos": 34,
        "width": 16,
        "height": 11,
        "widget": {
          "title": "SDK Version",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "minAlignmentPeriod": "60s",
                "plotType": "STACKED_AREA",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_COUNT",
                      "groupByFields": [
                        "metric.label.\"ssb_version_sdk\"",
                        "metric.label.\"ssb_version_http_client\"",
                        "metric.label.\"ssb_version_grpc\"",
                        "metric.label.\"ssb_version\""
                      ],
                      "perSeriesAligner": "ALIGN_DELTA"
                    },
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\""
                  }
                }
              }
            ],
            "thresholds": [],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            }
          }
        }
      }
    ]
  },
  "labels": {}
}
EOF
}

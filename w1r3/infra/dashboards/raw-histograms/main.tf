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

resource "google_monitoring_dashboard" "raw-histogram" {
  dashboard_json = <<EOF
{
    "displayName": "W1R3 - Raw Histograms",
    "dashboardFilters": [
      {
        "labelKey": "ssb_transport",
        "filterType": "METRIC_LABEL"
      },
      {
        "labelKey": "ssb_op",
        "filterType": "METRIC_LABEL"
      },
      {
        "labelKey": "ssb_language",
        "filterType": "METRIC_LABEL"
      },
      {
        "labelKey": "ssb_object_size",
        "filterType": "METRIC_LABEL"
      }
    ],
    "mosaicLayout": {
      "columns": 48,
      "tiles": [
        {
          "width": 24,
          "height": 16,
          "widget": {
            "title": "CPU / Byte",
            "xyChart": {
              "chartOptions": {
                "mode": "COLOR"
              },
              "dataSets": [
                {
                  "breakdowns": [],
                  "dimensions": [],
                  "measures": [],
                  "minAlignmentPeriod": "60s",
                  "plotType": "HEATMAP",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\""
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
        },
        {
          "yPos": 16,
          "width": 24,
          "height": 16,
          "widget": {
            "title": "Latency",
            "xyChart": {
              "chartOptions": {
                "mode": "COLOR"
              },
              "dataSets": [
                {
                  "minAlignmentPeriod": "60s",
                  "plotType": "HEATMAP",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "groupByFields": [],
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
        },
        {
          "widget": {
            "title": "Generic Task - Operation Latency [COUNT]",
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
                          "metric.label.\"ssb_version_grpc\"",
                          "metric.label.\"ssb_version_http_client\""
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
          },
          "height": 16,
          "width": 24,
          "xPos": 24
        },
        {
          "widget": {
            "title": "Generic Task - Operation Latency [COUNT]",
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
                          "metric.label.\"ssb_language\"",
                          "resource.label.\"location\""
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
          },
          "height": 16,
          "width": 24,
          "xPos": 24,
          "yPos": 16
        }
      ]
    },
    "labels": {}
}
    
EOF
}

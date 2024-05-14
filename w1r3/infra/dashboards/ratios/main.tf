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
    ignore_changes  = [dashboard_json]
  }
  dashboard_json = <<EOF
{
  "displayName": "W1R3 - Ratios",
  "dashboardFilters": [
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_op",
      "templateVariable": ""
    },
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_deployment",
      "stringValue": "mig",
      "templateVariable": ""
    },
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_language",
      "templateVariable": ""
    }
  ],
  "mosaicLayout": {
    "columns": 48,
    "tiles": [
      {
        "yPos": 16,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "GRPC+DP latency / JSON latency for 2MiB objects: [50TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilterRatio": {
                    "denominator": {
                      "aggregation": {
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\" metric.label.\"ssb_object_size\"=\"2097152\""
                    },
                    "numerator": {
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\" metric.label.\"ssb_object_size\"=\"2097152\""
                    }
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
        "width": 24,
        "height": 16,
        "widget": {
          "title": "GRPC+DP latency / JSON latency for 100MB objects: [50TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilterRatio": {
                    "denominator": {
                      "aggregation": {
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\" metric.label.\"ssb_object_size\"=\"100000000\""
                    },
                    "numerator": {
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\" metric.label.\"ssb_object_size\"=\"100000000\""
                    }
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
        "yPos": 32,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "GRPC+DP latency / JSON latency for 100KB objects: [50TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "breakdowns": [],
                "dimensions": [],
                "measures": [],
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilterRatio": {
                    "denominator": {
                      "aggregation": {
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\" metric.label.\"ssb_object_size\"=\"100000\""
                    },
                    "numerator": {
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\" metric.label.\"ssb_object_size\"=\"100000\""
                    }
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
        "yPos": 48,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "ssb/w1r3/latency [COUNT]",
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
                "plotType": "STACKED_AREA",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "crossSeriesReducer": "REDUCE_COUNT",
                      "groupByFields": [
                        "metric.label.\"ssb_version_sdk\"",
                        "metric.label.\"ssb_language\"",
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
      },
      {
        "xPos": 24,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "GRPC+DP  / JSON CPU for 100MB objects: [50TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilterRatio": {
                    "denominator": {
                      "aggregation": {
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\" metric.label.\"ssb_object_size\"=\"100000000\""
                    },
                    "numerator": {
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\" metric.label.\"ssb_object_size\"=\"100000000\""
                    }
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
        "xPos": 24,
        "yPos": 16,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "GRPC+DP  / JSON CPU for 2MiB objects: [50TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilterRatio": {
                    "denominator": {
                      "aggregation": {
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\" metric.label.\"ssb_object_size\"=\"2097152\""
                    },
                    "numerator": {
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\" metric.label.\"ssb_object_size\"=\"2097152\""
                    }
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
        "xPos": 24,
        "yPos": 32,
        "width": 24,
        "height": 16,
        "widget": {
          "title": "GRPC+DP  / JSON CPU for 2MiB objects: [50TH PERCENTILE]",
          "xyChart": {
            "chartOptions": {
              "mode": "COLOR"
            },
            "dataSets": [
              {
                "plotType": "LINE",
                "targetAxis": "Y1",
                "timeSeriesQuery": {
                  "timeSeriesFilterRatio": {
                    "denominator": {
                      "aggregation": {
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\" metric.label.\"ssb_object_size\"=\"100000\""
                    },
                    "numerator": {
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\" metric.label.\"ssb_object_size\"=\"100000\""
                    }
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

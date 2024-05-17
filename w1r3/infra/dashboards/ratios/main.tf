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
        "xPos": 16,
        "yPos": 12,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON latency for 2MiB objects: [50TH PERCENTILE]",
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
        "yPos": 12,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON latency for 100MB objects: [50TH PERCENTILE]",
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
        "xPos": 32,
        "yPos": 12,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON latency for 100KB objects: [50TH PERCENTILE]",
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
        "yPos": 72,
        "width": 48,
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
        "yPos": 32,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON CPU for 100MB objects: [50TH PERCENTILE]",
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
        "xPos": 16,
        "yPos": 32,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON CPU for 2MiB objects: [50TH PERCENTILE]",
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
        "xPos": 32,
        "yPos": 32,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON CPU for 100KB objects: [50TH PERCENTILE]",
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
      },
      {
        "yPos": 8,
        "width": 48,
        "height": 4,
        "widget": {
          "title": "Latency",
          "sectionHeader": {
            "dividerBelow": false,
            "subtitle": ""
          }
        }
      },
      {
        "width": 48,
        "height": 8,
        "widget": {
          "title": "Direct Path vs. JSON Comparisons",
          "text": {
            "content": "These charts compare the formance of GCS+GRPC vs. JSON. The ratios are expressed as \"GRPC+DP / JSON percentage\". For example, if GRPC+DP takes 0.8 seconds to perform an operation, and JSON takes 1 seconds, then the chart will show \"80%\". That is GRPC+DP only requires 80% of the time vs. the time required by JSON.  Most people would say that that is a 20% improvement.\n\nIn all cases **lower is better**.\n",
            "format": "MARKDOWN",
            "style": {
              "backgroundColor": "#FFFFFF",
              "fontSize": "FS_LARGE",
              "horizontalAlignment": "H_LEFT",
              "padding": "P_EXTRA_SMALL",
              "pointerLocation": "POINTER_LOCATION_UNSPECIFIED",
              "textColor": "#212121",
              "verticalAlignment": "V_TOP"
            }
          }
        }
      },
      {
        "yPos": 28,
        "width": 48,
        "height": 4,
        "widget": {
          "title": "CPU",
          "sectionHeader": {
            "dividerBelow": false,
            "subtitle": ""
          }
        }
      },
      {
        "yPos": 48,
        "width": 48,
        "height": 4,
        "widget": {
          "title": "Memory",
          "sectionHeader": {
            "dividerBelow": false,
            "subtitle": ""
          }
        }
      },
      {
        "yPos": 52,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON Memory for 100MB objects: [50TH PERCENTILE]",
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
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\" metric.label.\"ssb_object_size\"=\"100000000\""
                    },
                    "numerator": {
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\" metric.label.\"ssb_object_size\"=\"100000000\""
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
        "xPos": 16,
        "yPos": 52,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON Memory for 2MiB objects: [50TH PERCENTILE]",
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
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\" metric.label.\"ssb_object_size\"=\"2097152\""
                    },
                    "numerator": {
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\" metric.label.\"ssb_object_size\"=\"2097152\""
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
        "xPos": 32,
        "yPos": 52,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON Memory for 100KB objects: [50TH PERCENTILE]",
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
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\" metric.label.\"ssb_object_size\"=\"100000\""
                    },
                    "numerator": {
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": [],
                        "perSeriesAligner": "ALIGN_DELTA"
                      },
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\" metric.label.\"ssb_object_size\"=\"100000\""
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
        "yPos": 68,
        "width": 48,
        "height": 4,
        "widget": {
          "title": "Deployed Versions",
          "sectionHeader": {
            "dividerBelow": true,
            "subtitle": ""
          }
        }
      }
    ]
  },
  "labels": {}
}
EOF
}

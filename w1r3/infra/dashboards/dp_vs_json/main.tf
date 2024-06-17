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

resource "google_monitoring_dashboard" "dp_vs_json" {
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [dashboard_json]
  }
  dashboard_json = <<EOF
{
  "displayName": "SSBv2/w1r3 comparison",
  "dashboardFilters": [
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_op",
      "stringValue": "READ[0]",
      "templateVariable": ""
    },
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_transfer_type",
      "stringValue": "",
      "templateVariable": ""
    },
    {
      "filterType": "METRIC_LABEL",
      "labelKey": "ssb_deployment",
      "stringValue": "mig",
      "templateVariable": ""
    },
    {
      "labelKey": "ssb_object_size",
      "stringValue": "100000000",
      "filterType": "METRIC_LABEL"
    },
    {
      "labelKey": "ssb_language",
      "stringValue": "cpp",
      "filterType": "METRIC_LABEL"
    },
    {
      "labelKey": "ssb_region",
      "stringValue": "us-central1",
      "filterType": "METRIC_LABEL"
    }
  ],
  "labels": {},
  "mosaicLayout": {
    "columns": 48,
    "tiles": [
      {
        "width": 48,
        "height": 24,
        "xPos": 0,
        "yPos": 0,
        "widget": {
          "title": "Direct Path vs. JSON Comparisons",
          "collapsibleGroup": {
            "collapsed": false
          }
        }
      },
      {
        "width": 48,
        "height": 24,
        "xPos": 0,
        "yPos": 0,
        "widget": {
          "title": "",
          "text": {
            "content": "These charts compare the performance of GCS+GRPC vs. JSON.\n\nSelf link: [go/ssbv2:w1r3:compare](http://go/ssbv2:w1r3:compare)\n\n### Layout\n\nThis dashboard is laid out in a tabular fashion. Columns correspond to the transport/comparison, rows correspond to individual metrics.\n\n### Workload\n\nWrite Once Read Three times (w1r3).\n\n1. Pick an object size {`100000`, `2097152`, `100000000`} ({`100KB`, `2MiB`, `100MB`})\n2. Upload an object from memory using either {`RESUMABLE`, `SINGLE-SHOT`} strategy\n3. Download the created object from `0`-`EOF`\n4. repeat download two more times\n5. goto 1\n\n### Filter Dimensions\n\nUse the dashboard filters at the top to choose the dimensions. A value should be selected for each of Operation, Language, Object Size otherwise all values will be included.\n\n* Operations:\n  * `ssb_op` {`RESUMABLE`, `SINGLE-SHOT`, `READ[0]`, `READ[1]`, `READ[2]`}\n  * `ssb_transfer_type` {`UPLOAD`, `DOWNLOAD`} -- `UPLOAD` == `ssb_op in {RESUMABLE, SINGLE_SHOT}`, `DOWNLOAD` == `ssb_op in {READ[0], READ[1], READ[2]}`\n* Language: `ssb_language` {`cpp`, `go`, `java`}\n* Object Size: `ssb_object_size` {`100000`, `2097152`, `100000000`}\n* GCP Region: `ssb_region` {`us-central1`, `us-east1`}\n",
            "format": "MARKDOWN",
            "style": {
              "backgroundColor": "#FFFFFF",
              "textColor": "#212121",
              "horizontalAlignment": "H_LEFT",
              "verticalAlignment": "V_TOP",
              "padding": "P_EXTRA_SMALL",
              "fontSize": "FS_EXTRA_LARGE",
              "pointerLocation": "POINTER_LOCATION_UNSPECIFIED"
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },



      {
        "width": 16,
        "height": 12,
        "xPos": 0,
        "yPos": 24,
        "widget": {
          "title": "JSON",
          "text": {
            "content": "Operations performed using GCS JSON Api with traffic flowing via CloudPath",
            "format": "MARKDOWN",
            "style": {
              "backgroundColor": "#FFFFFF",
              "fontSize": "FS_EXTRA_LARGE",
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
        "width": 16,
        "height": 12,
        "xPos": 16,
        "yPos": 24,
        "widget": {
          "title": "GRPC+DP",
          "text": {
            "content": "Operations performed using GCS gRPC Api with traffic flowing via DirectPath",
            "format": "MARKDOWN",
            "style": {
              "backgroundColor": "#FFFFFF",
              "fontSize": "FS_EXTRA_LARGE",
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
        "width": 16,
        "height": 12,
        "xPos": 32,
        "yPos": 24,
        "widget": {
          "title": "GRPC+DP / JSON",
          "text": {
            "content": "Ratios comparing performance of GRPC+DP vs JSON expressed as \"GRPC+DP / JSON percentage\".\n\n**Beware: ratios can appear very bad, even though the absolute numbers are not terrible.**\n\nIn all cases **lower is better**.\n\nFor example, if GRPC+DP takes 0.8 seconds to perform an operation, and JSON takes 1 seconds, then the chart will show \"80%\". That is GRPC+DP only requires 80% of the time vs. the time required by JSON.  Most people would say that that is a 20% improvement.\n",
            "format": "MARKDOWN",
            "style": {
              "backgroundColor": "#FFFFFF",
              "fontSize": "FS_EXTRA_LARGE",
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
        "xPos": 0,
        "yPos": 34,
        "width": 48,
        "height": 4,
        "widget": {
          "title": "Latency",
          "sectionHeader": {
            "subtitle": "Wall time it takes to perform the operation",
            "dividerBelow": false
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 0,
        "yPos": 38,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "JSON Latency",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_DELTA",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": []
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "HEATMAP",
                "legendTemplate": "",
                "minAlignmentPeriod": "60s",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 16,
        "yPos": 38,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP Latency",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_DELTA",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": []
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "HEATMAP",
                "legendTemplate": "",
                "minAlignmentPeriod": "60s",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 32,
        "yPos": 38,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON latency [50TH PERCENTILE]",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilterRatio": {
                    "numerator": {
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\"",
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "perSeriesAligner": "ALIGN_DELTA",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": []
                      }
                    },
                    "denominator": {
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\"",
                      "aggregation": {
                        "perSeriesAligner": "ALIGN_DELTA",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": []
                      }
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "LINE",
                "legendTemplate": "",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [
              {
                "label": "",
                "targetAxis": "Y1",
                "value": 0
              }
            ],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },


      {
        "xPos": 0,
        "yPos": 54,
        "width": 48,
        "height": 4,
        "widget": {
          "title": "CPU",
          "sectionHeader": {
            "subtitle": "Amount of CPU time used per byte to perform the operation",
            "dividerBelow": false
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 0,
        "yPos": 58,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "JSON CPU / Byte",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_DELTA",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": []
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "HEATMAP",
                "legendTemplate": "",
                "minAlignmentPeriod": "60s",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 16,
        "yPos": 58,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP CPU / Byte",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_DELTA",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": []
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "HEATMAP",
                "legendTemplate": "",
                "minAlignmentPeriod": "60s",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 32,
        "yPos": 58,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON CPU / Byte [50TH PERCENTILE]",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilterRatio": {
                    "numerator": {
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\"",
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "perSeriesAligner": "ALIGN_DELTA",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": []
                      }
                    },
                    "denominator": {
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/cpu\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\"",
                      "aggregation": {
                        "perSeriesAligner": "ALIGN_DELTA",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": []
                      }
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "LINE",
                "legendTemplate": "",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [
              {
                "label": "",
                "targetAxis": "Y1",
                "value": 0
              }
            ],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },


      {
        "xPos": 0,
        "yPos": 74,
        "width": 48,
        "height": 4,
        "widget": {
          "title": "Memory",
          "sectionHeader": {
            "subtitle": "Amount of memory used per byte to perform the operation",
            "dividerBelow": false
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 0,
        "yPos": 78,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "JSON Memory",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_DELTA",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": []
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "HEATMAP",
                "legendTemplate": "",
                "minAlignmentPeriod": "60s",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 16,
        "yPos": 78,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP Memory",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_DELTA",
                      "crossSeriesReducer": "REDUCE_SUM",
                      "groupByFields": []
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "HEATMAP",
                "legendTemplate": "",
                "minAlignmentPeriod": "60s",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 32,
        "yPos": 78,
        "width": 16,
        "height": 16,
        "widget": {
          "title": "GRPC+DP / JSON Memory [50TH PERCENTILE]",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilterRatio": {
                    "numerator": {
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"GRPC+DP\"",
                      "aggregation": {
                        "alignmentPeriod": "1800s",
                        "perSeriesAligner": "ALIGN_DELTA",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": []
                      }
                    },
                    "denominator": {
                      "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/memory\" resource.type=\"generic_task\" metric.label.\"ssb_transport\"=\"JSON\"",
                      "aggregation": {
                        "perSeriesAligner": "ALIGN_DELTA",
                        "crossSeriesReducer": "REDUCE_PERCENTILE_50",
                        "groupByFields": []
                      }
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "LINE",
                "legendTemplate": "",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [
              {
                "label": "",
                "targetAxis": "Y1",
                "value": 0
              }
            ],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      },



      {
        "xPos": 0,
        "yPos": 94,
        "width": 48,
        "height": 4,
        "widget": {
          "title": "Deployed Versions",
          "sectionHeader": {
            "subtitle": "",
            "dividerBelow": true
          },
          "visualElementId": 0,
          "id": ""
        }
      },
      {
        "xPos": 0,
        "yPos": 98,
        "width": 48,
        "height": 16,
        "widget": {
          "title": "deployed versions [COUNT]",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "metric.type=\"workload.googleapis.com/ssb/w1r3/latency\" resource.type=\"generic_task\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_DELTA",
                      "crossSeriesReducer": "REDUCE_COUNT",
                      "groupByFields": [
                        "metric.label.\"ssb_language\"",
                        "metric.label.\"ssb_version_sdk\"",
                        "metric.label.\"ssb_version\""
                      ]
                    }
                  },
                  "unitOverride": "",
                  "outputFullDuration": false
                },
                "plotType": "STACKED_AREA",
                "legendTemplate": "",
                "minAlignmentPeriod": "60s",
                "targetAxis": "Y1",
                "dimensions": [],
                "measures": [],
                "breakdowns": []
              }
            ],
            "thresholds": [],
            "yAxis": {
              "label": "",
              "scale": "LINEAR"
            },
            "chartOptions": {
              "mode": "COLOR",
              "showLegend": false,
              "displayHorizontal": false
            }
          },
          "visualElementId": 0,
          "id": ""
        }
      }
    ]
  }
}
EOF
}

---
title: elasticsearch(4) - 常用Composite聚合查询
date: 2021-08-30 23:25:06
tags:
  - 聚合查询
  - elasticsearch
categories:
  - 分布式系统
  - 搜索
  - elasticsearch
---

es常见的聚合查询有composite，现在案例主要是composite聚合例子。

# Bool和Nested查询（订单结算查询）

```json
GET /order/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "term": {
            "courseId": {
              "value": "1"
            }
          }
        },
        {
          "nested": {
            "path": "sharer",
            "query": {
              "term": {
                "sharer.sharerId": {
                  "value": "24"
                }
              }
            }
          }
        },
        {
          "range": {
            "term": {
              "gte": 201103,
              "lte": 202202
            }
          }
        },
        {
          "term": {
            "categoryId": {
              "value": "1"
            }
          }
        },
        {
          "range": {
            "payMonth": {
              "gte": 201103,
              "lte": 202202
            }
          }
        }
      ]
    }
  },
  "sort": [
    {
      "orderId": {
        "order": "desc"
      }
    },
    {
      "term": {
        "order": "desc"
      }
    }
  ],
  "from": 0,
  "size": 20
}
```



# Composite聚合和嵌套聚合（费用统计）

```json
GET /order/_search?size=0
{
  "query": {
    "bool": {
      "must": [
        {
          "terms": {
            "courseId": [
              "16861",
              "25590"
            ]
          }
        },
        {
          "term": {
            "sharerTerm": {
              "value": "202003"
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "compositeData": {
      "composite": {
        "sources": [
          {
            "sharerId": {
              "terms": {
                "field": "sharerId"
              }
            }
          },
          {
            "beginTerm": {
              "terms": {
                "field": "sharerTerm"
              }
            }
          },
          {
            "courseId": {
              "terms": {
                "field": "courseId"
              }
            }
          }
        ]
      },
      "aggs": {
        "amortizesNest": {
          "nested": {
            "path": "sharerAmortizes"
          },
          "aggs": {
            "amortizes.term": {
              "filter": {
                "term": {
                  "sharerAmortizes.term": 202002
                }
              },
              "aggs": {
                "amortizes.amount": {
                  "sum": {
                    "field": "sharerAmortizes.amount"
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```



# Compsite聚合和Sum统计（支付摊期统计）

```json
GET /order/_search?size=0&request_cache=true
{
  "query": {
    "bool": {
      "must": [
        {
          "range": {
            "payMonth": {
              "gte": 202110,
              "lte": 202110
            }
          }
        },
        {
          "range": {
            "term": {
              "gte": 202110
            }
          }
        },
        {
          "term": {
            "courseId": {
              "value": "110872"
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "buckets": {
      "composite": {
        "size": 1000,
        "sources": [
          {
            "courseId": {
              "terms": {
                "field": "courseId"
              }
            }
          },
          {
            "term": {
              "terms": {
                "field": "term"
              }
            }
          }
        ]
      },
      "aggs": {
        "earningSum": {
          "sum": {
            "field": "earningSum"
          }
        },
        "goodsEarning.1": {
          "sum": {
            "field": "goodsEarning.1"
          }
        },
        "goodsEarning.2": {
          "sum": {
            "field": "goodsEarning.2"
          }
        },
        "goodsEarning.3": {
          "sum": {
            "field": "goodsEarning.3"
          }
        },
        "goodsEarning.4": {
          "sum": {
            "field": "goodsEarning.4"
          }
        },
        "goodsEarning.5": {
          "sum": {
            "field": "goodsEarning.5"
          }
        },
        "courseEarning": {
          "sum": {
            "field": "courseEarning"
          }
        },
        "cost": {
          "sum": {
            "field": "cost"
          }
        },
        "selfCost": {
          "sum": {
            "field": "selfCost"
          }
        },
        "allCost": {
          "sum": {
            "field": "allCost"
          }
        },
        "deliveryTaxedFee": {
          "sum": {
            "field": "deliveryTaxedFee"
          }
        },
        "deliveryFee": {
          "sum": {
            "field": "deliveryFee"
          }
        },
        "sharerSettles": {
          "nested": {
            "path": "sharerSettles"
          },
          "aggs": {
            "sharerSettles.sharerId": {
              "terms": {
                "field": "sharerSettles.sharerId",
                "size": 1000,
                "shard_size": 1000,
                "collect_mode": "breadth_first"
              },
              "aggs": {
                "sharerSettles.rate": {
                  "terms": {
                    "field": "sharerSettles.rate_key",
                    "size": 100,
                    "shard_size": 100,
                    "collect_mode": "breadth_first"
                  },
                  "aggs": {
                    "sharerSettles.shareSum": {
                      "sum": {
                        "field": "sharerSettles.shareSum"
                      }
                    },
                    "sharerSettles.share": {
                      "sum": {
                        "field": "sharerSettles.share"
                      }
                    },
                    "sharerSettles.cost": {
                      "sum": {
                        "field": "sharerSettles.cost"
                      }
                    },
                    "sharerSettles.shareCost": {
                      "sum": {
                        "field": "sharerSettles.shareCost"
                      }
                    },
                    "sharerSettles.taxedEarning": {
                      "sum": {
                        "field": "sharerSettles.taxedEarning"
                      }
                    },
                    "sharerSettles.earning": {
                      "sum": {
                        "field": "sharerSettles.earning"
                      }
                    },
                    "sharerSettles.rate": {
                      "sum": {
                        "field": "sharerSettles.rate"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

# Composite聚合（支付方式统计）

```json
GET /order/_search?size=0&request_cache=true
{
  "query": {
    "bool": {
      "must": [
        {
          "range": {
            "payMonth": {
              "gte": 202010,
              "lte": 202011
            }
          }
        },
        {
          "range": {
            "term": {
              "gte": 202010,
              "lte": 202011
            }
          }
        }
      ]
    }
  },
  "aggs": {
    "buckets": {
      "composite": {
        "size": 1000,
        "sources": [
          {
            "courseId": {
              "terms": {
                "field": "courseId",
                "order": "desc"
              }
            }
          },
          {
            "term": {
              "terms": {
                "field": "term",
                "order": "asc"
              }
            }
          },
          {
            "payFrom": {
              "terms": {
                "field": "payFrom",
                "missing_bucket": true,
                "order": "asc"
              }
            }
          }
        ]
      },
      "aggs": {
        "courseEarning": {
          "sum": {
            "field": "courseEarning"
          }
        },
        "goodsEarning.1": {
          "sum": {
            "field": "goodsEarning.1"
          }
        },
        "goodsEarning.2": {
          "sum": {
            "field": "goodsEarning.2"
          }
        },
        "goodsEarning.3": {
          "sum": {
            "field": "goodsEarning.3"
          }
        },
        "goodsEarning.4": {
          "sum": {
            "field": "goodsEarning.4"
          }
        },
        "goodsEarning.5": {
          "sum": {
            "field": "goodsEarning.5"
          }
        },
        "poundage": {
          "sum": {
            "field": "poundage"
          }
        },
        "agentFee": {
          "sum": {
            "field": "agentFee"
          }
        },
        "deliveryTaxedFee": {
          "sum": {
            "field": "deliveryTaxedFee"
          }
        },
        "deliveryFee": {
          "sum": {
            "field": "deliveryFee"
          }
        }
      }
    }
  }
}
```


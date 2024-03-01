---
title: elasticsearch(3)- 聚合查询性能优化：从terms聚合到composite聚合
date: 2021-08-29 23:25:06
tags:
  - composite聚合
  - elasticsearch
categories:
  - 分布式系统
  - 搜索
  - elasticsearch
---

# 问题背景
查找19年到现在数据很慢，terms聚合性能问题。订单量统计(2021-11-11⽇统计) 来⾃：X_N表。

| 项⽬ | 订单量  |
| ---- | ------- |
| X1   | 176386  |
| X2   | 774911  |
| X3   | 1183295 |
| X4   | 1567748 |
| X5   | 3567914 |

当订单量达到500w-1000w以上，terms聚合性能很差。

# 解决方法

性能优化是把es的terms-aggregation改成composite aggregation。terms嵌套聚合改成composite聚合的**缺点：相对嵌套式terms，缺乏的功能是⽆法执⾏中间层上的⼦聚合，需要再对中间层进⾏额外的聚合请求。所以会极⼤增加代码的编写**。

**terms**聚合：[参考](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-terms-aggregation.html)

**terms**聚合不精确问题(5.3有说明)：[参考](https://www.elastic.co/guide/en/elasticsearch/reference/5.3/search-aggregations-bucket-terms-aggregation.html#search-aggregations-bucket-terms-aggregation-approximate-counts)

**composite聚合**：[参考](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-composite-aggregation.html)

**multi-terms聚合**(7.15才有特性)：[参考](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-multi-terms-aggregation.html)



# 案例分析

```java
Map<Integer, Map<String, Cat1Agg>> aggs(String index, Param param) {
        AggregationBuilder amountAgg = AggregationBuilders.sum("amount").field("amount");
        AggregationBuilder vendorModeAgg = AggregationBuilders.terms("vendorMode").field("vendorMode")
                .size(1000).shardSize(1000).collectMode(BREADTH_FIRST)
                .subAggregation(amountAgg);
        AggregationBuilder categoryAgg = AggregationBuilders.terms("category").field("category")
                .size(1000).shardSize(1000).collectMode(BREADTH_FIRST)
                .subAggregation(amountAgg).subAggregation(vendorModeAgg);
        AggregationBuilder category1Agg = AggregationBuilders.terms("category1").field("category1")
                .size(1000).shardSize(1000).collectMode(BREADTH_FIRST).missing("⽆分类")
                .subAggregation(amountAgg).subAggregation(categoryAgg);
        AggregationBuilder termAgg = AggregationBuilders.terms("term").field("term")
                .size(1000).shardSize(1000).collectMode(BREADTH_FIRST)
                .subAggregation(category1Agg);
        SearchRequestBuilder req = esClient.prepareSearch(index).setSize(0).setQuery(QueryBuilders.boolQuery().filter(param.toE
                .addAggregation(termAgg);
        SearchResponse res = req.get(Es.TimeOut_30m);
        if (log.isTraceEnabled()) log.trace("⽀付⾦额（含退款）流⽔统计:{}\n{}", req, res);
        Map<Integer, Map<String, Cat1Agg>> statis = new TreeMap<>();
        Terms termRsts = res.getAggregations().get("term");
        for (Terms.Bucket termRst : termRsts.getBuckets()) {
            int month = termRst.getKeyAsNumber().intValue();
            Map<String, Cat1Agg> monthStatis = new TreeMap<>();
            Terms cat1Rsts = termRst.getAggregations().get("category1");
            for (Terms.Bucket cat1Rst : cat1Rsts.getBuckets()) {
                String cat1 = cat1Rst.getKeyAsString();
                Cat1Agg cat1Agg = new Cat1Agg();
                cat1Agg.amount = new BigDecimal(((Sum) cat1Rst.getAggregations().get("amount")).getValueAsString()).setScale(5,
                        Terms catRsts = cat1Rst.getAggregations().get("category");
                for (Terms.Bucket catRst : catRsts.getBuckets()) {
                    String cat = catRst.getKeyAsString();
                    CatAgg catAgg = new CatAgg();
                    catAgg.amount = new BigDecimal(((Sum) catRst.getAggregations().get("amount")).getValueAsString()).setScale(
                            Terms vendorModeRsts = catRst.getAggregations().get("vendorMode");
                    for (Terms.Bucket vendorModeRst : vendorModeRsts.getBuckets()) {
                        VendorMode vendorMode = IntEnum.valueOf(VendorMode.class, vendorModeRst.getKeyAsNumber().intValue());
                        if (vendorMode == null) continue;
                        BigDecimal amount = new BigDecimal(((Sum) vendorModeRst.getAggregations().get("amount")).getValueAsStri
                                catAgg.vendorModeAmounts.put(vendorMode, amount);
                    }
                    cat1Agg.catAmounts.put(cat, catAgg);
                }
                monthStatis.put(cat1, cat1Agg);
            }
            statis.put(month, monthStatis);
        }
        return statis;
    }
```



# terms聚合

```json
GET order/_search?size=0{
    "query": {
        "bool": {
            "must": [
                {
                    "range": {
                        "term": {
                            "gte": 202111,
                            "lte": 202111
                        }
                    }
                }
            ]
        }
    },
    "aggs": {
        "term": {
            "terms": {
                "field": "term",
                "size": 1000,
                "shard_size": 1000
            },
            "aggs": {
                "category1": {
                    "terms": {
                        "field": "category1",
                        "size": 1000,
                        "shard_size": 1000
                    },
                    "aggs": {
                        "amount": {
                            "sum": {
                                "field": "amount"
                            }
                        },
                        "category": {
                            "terms": {
                                "field": "category",
                                "size": 1000,
                                "shard_size": 1000
                            },
                            "aggs": {
                                "amount": {
                                    "sum": {
                                        "field": "amount"
                                    }
                                },
                                "vendorMode": {
                                    "terms": {
                                        "field": "vendorMode",
                                        "size": 1000,
                                        "shard_size": 1000
                                    },
                                    "aggs": {
                                        "amount": {
                                            "sum": {
                                                "field": "amount"
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



# 优化成composite聚合

多轮composite聚合，每次composite聚合需要遍历所有分⽚ ，并且遍历多次。

```json
GETorder/_search?size=0{
    "query": {
        "bool": {
            "must": [
                {
                    "range": {
                        "term": {
                            "gte": 202111,
                            "lte": 202111
                        }
                    }
                }
            ]
        }
    },
    "aggs": {
        "statis": {
            "composite": {
                "sources": [
                    {
                        "term": {
                            "terms": {
                                "field": "term"
                            }
                        }
                    },
                    {
                        "category1": {
                            "terms": {
                                "field": "category1"
                            }
                        }
                    },
                    {
                        "category": {
                            "terms": {
                                "field": "category"
                            }
                        }
                    },
                    {
                        "vendorMode": {
                            "terms": {
                                "field": "vendorMode"
                            }
                        }
                    }
                ]
            }
        },
        "amount": {
            "sum": {
                "field": "amount"
            }
        }
    }
}
```


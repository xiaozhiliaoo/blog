---
title: elasticsearch(2)-query的match和term区别
date: 2021-08-29 21:12:04
tags: 
  - 分布式系统泛型
  - elasticsearch
categories:
  - 分布式系统
  - 搜索
  - elasticsearch
---

# 区别

match query在索引和查询时分词，term query在索引时候分词，在查询时候不分词。

match query是全文搜索，term query是词项搜索。

match query不是精确搜索，想要精确搜索，使用term keyword query.

# 例子

```
DELETE test
PUT test/_doc/1
{
  "content":"Hello World"
}
```



# match query

```
POST test/_search
{
  "profile": "true",
  "query": {
    "match": {
      "content": "hello world"
    }
  }
}
```

有结果返回。es的standard分词器会将Hello World索引数据时候，会分解成hello，world.

而match query会将content进行分词为hello，world。所以可以搜到。



```
POST test/_search
{
  "profile": "true",
  "query": {
    "match": {
      "content.keyword": "Hello World"
    }
  }
}
```

有结果返回。match query会将内容进行分词为hello，world，所以可以查到。



```
POST test/_search
{
  "profile": "true",
  "query": {
    "match": {
      "content.keyword": "hello world"
    }
  }
}
```

无结果返回。match query keyword会将match query转换为term query，keyword搜索并不会分词，所以搜索不到。





```
POST test/_search
{
  "profile": "true",
  "query": {
    "match": {
      "content": "Hello World"
    }
  }
}
```

有结果返回。match query会分词，将match query转换为term query



# term query

```
POST test/_search
{
  "profile": "true",
  "query": {
    "term": {
      "content": "hello world"
    }
  }
}
```

无结果返回。term query不会分词，hello world查询不到，因为index时候Hello World被转换成hello，world.



```
POST test/_search
{
  "profile": "true",
  "query": {
    "term": {
      "content": "Hello World"
    }
  }
}
```

无结果返回。term query不会分词，数据在content被分成了hello，world.hello world查询不到，因为index时候Hello World被转换成hello，world.



```
POST test/_search
{
  "profile": "true",
  "query": {
    "term": {
      "content.keyword": "hello world"
    }
  }
}
```

无结果返回，没有hello world，索引时候Hello World分解成hello，world两个词.



```
POST test/_search
{
  "profile": "true",
  "query": {
    "term": {
      "content.keyword": "Hello World"
    }
  }
}
```

有结果返回。精确匹配。term query的精确匹配用keyword。




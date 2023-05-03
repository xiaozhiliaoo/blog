---
title: elasticsearch(1)-集群,节点与分片，理解查找过程
date: 2021-08-29 02:33:46
tags: 
  - 分布式系统泛型
  - elasticsearch
categories:
  - 分布式系统
  - 搜索
  - elasticsearch
---

# 单机多节点集群

```
./elasticsearch -E node.name=node0 -E cluster.name=geektime -E path.data=node0_data -d
./elasticsearch -E node.name=node1 -E cluster.name=geektime -E path.data=node1_data -d
./elasticsearch -E node.name=node2 -E cluster.name=geektime -E path.data=node2_data -d
./elasticsearch -E node.name=node3 -E cluster.name=geektime -E path.data=node3_data -d
```



可以通过`GET /_cat/nodes?v`查看node0是主节点。



# 创建索引与分片

es在一个有4个节点的集群上创建一个索引，并且索引里面只包含了一个文档，那么这份文档的存储和节点分布是什么样呢？



```
DELETE test
PUT test
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 2
  }
}
```

实际在4个节点总共有9个分片，3个主分片，6个副本分片。



```
POST test/_doc
{
  "company":"baidu"
}
```



```
GET test/_search
{
  "profile": "true", 
  "query": {
    "term": {
      "company": {
        "value": "baidu"
      }
    }
  }
}
```



```
查看索引在节点的分配
GET /_cat/shards?v&index=test
```

显示结果如下：

```
index shard prirep state   docs store ip        node
test  1     r      STARTED    0  230b 127.0.0.1 node2
test  1     p      STARTED    0  230b 127.0.0.1 node3
test  1     r      STARTED    0  230b 127.0.0.1 node0
test  2     r      STARTED    0  230b 127.0.0.1 node1
test  2     r      STARTED    0  230b 127.0.0.1 node2
test  2     p      STARTED    0  230b 127.0.0.1 node0
test  0     r      STARTED    1 3.4kb 127.0.0.1 node1
test  0     p      STARTED    1 3.4kb 127.0.0.1 node2
test  0     r      STARTED    1 3.4kb 127.0.0.1 node3
```



<img src="/images/shard-legend.png"/>



可以看到创建一个索引的时候，被分配到4个node，node0是主节点leader节点(图片有星号)，node2~node4是非leader节点。而company=baidu文档被创建时候，被分片到node1，node2，node3上面（docs=1），**每一个文档被分配到一个分片**，node2是primary shard，而node1，node3是replica shard. 而在搜索company=baidu时候，打开profile api，会发现数据查找经历了3个shard，分别是

```
"id" : "[S_H7_aQZQT6N1Xvak3Y5Gg][test][1]"
"id" : "[Y6x8KA6XQzaa4ebI2QKrZg][test][0]"
"id" : "[Y6x8KA6XQzaa4ebI2QKrZg][test][2]"
```

根据`GET /_nodes/_all/nodes` 可以获取到节点名字

```
node0：uvCcgxEFT82xFtQAv9aydA
node1：Y6x8KA6XQzaa4ebI2QKrZg
node2：S_H7_aQZQT6N1Xvak3Y5Gg
node3：BdHl3TItTv6B4BHm1DuwMA
```

可以得知，查找company=baidu时候，一定会查找三个分片（也就是**number_of_shards**的个数，primary和replica都有可能），profile api显示经历了1次node2[1]和2次node1[0]，node1[2]，恰好查找了三个分片0,1,2。但是文档存储在node1[0]，node2[0]，node3[0]，所以数据最终在node1[0]分片(**replica shard**)上找到了要查找的文档，在node1[2]，node2[1]并没有找到文档。每次重新执行的查找的时候，profile api也会动态变化，查询的节点和分片也会随之变化。（疑问：如果有50个节点，一个索引创建了3个分片(number_of_shards=3)，那么怎么知道需要遍历分片在哪里呢？而不是所有节点遍历一遍，也就是es怎么知道遍历哪些节点呢？所以es一定存了分片和）



# 索引常用DSL

## 查看节点详情

```
GET /_nodes
```



## 查看索引映射和配置

```
GET test
```



## 查看索引大小

```
GET /_cat/indices?v&index=test
```



## 查看segment

```
GET /_cat/segments?v&index=test
```


---
title: 惊奇的工程算法简介
date: 2021-01-03 19:37:35
tags: algorithm
categories:
  - 算法
  - 工程算法
---



# 简介

本系列主要介绍比较经典/常用的工程算法，理解这些算法非常有意义，对于程序优化有很有帮助，会发出惊奇的感慨。这里算法以工程为出发点，而非严谨意义上的数学证明算法。



# 工程算法分类

算法主要分为以下几类：

## 单机系统

1. Membership:   HashSet.constains, BitSet.get, Bloom Filter，Counting Bloom Filter
2. Cardinality:   HashSet.size, BitSet.cardinality, Linear counter，Log Log，HyperLogLog
3. Frequency: HashMap.put, HashMultiset.count, Count Sketch，Count-Min Sketch
4. Hash算法和一致性Hash算法
5. 时间轮算法：Hashed and Hierarchical Timing Wheel
6. 唯一ID生成器：snowflake，
7. 负载均衡算法：Round robin，Weighted round robin
8. 限流算法：Token Bucket，Leaky Bucket，Fixed Window，Sliding Log，Sliding Window
9. 缓存淘汰算法：LFU，LRU，FIFO

## 分布式系统

1. 共识算法：ZAB，Paxos，Raft，Viewstamped Replication，PBFT，Atomic Broadcast
2. 选举算法：Bully，Ring
3. 快照算法：Chandy Lamport，Lightweight Asynchronous Snapshots


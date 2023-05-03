---
title: 分布式事务解决方案
date: 2022-01-01 21:44:31
tags: 
  - 分布式事务
categories:
  - 分布式系统
---





# 前言

分布式事务划分为两个角度，1是存储层，也即数据库角度的分布式事务，多实现于分布式数据库事务 2是业务层，偏向于服务化系统以及业务系统的分布式事务。



# 存储层

[spanner](https://static.googleusercontent.com/media/research.google.com/zh-CN//archive/spanner-osdi2012.pdf)，[XA](https://en.wikipedia.org/wiki/X/Open_XA)([2pc](https://en.wikipedia.org/wiki/Two-phase_commit_protocol))，，[3pc](https://en.wikipedia.org/wiki/Three-phase_commit_protocol)，[percolator](https://storage.googleapis.com/pub-tools-public-publication-data/pdf/36726.pdf)(2pc)，[calvin](http://cs.yale.edu/homes/thomson/publications/calvin-sigmod12.pdf)，[apache omid](https://omid.incubator.apache.org/)



| 模型       | 数据模型  | 并发控制方案          | 隔离级别支持 | 限制                 |
| ---------- | --------- | --------------------- | ------------ | -------------------- |
| XA         | 不限      | 两阶段锁（悲观）      | 所有隔离级别 | 加读锁导致性能下降   |
| Percolator | Key-Value | 加锁(悲观) & MVCC     | SI           |                      |
| Omid       | Key-Value | 冲突检测(乐观) & MVCC | SI           |                      |
| Calvin     | 不限      | 确定性数据库          | Serializable | 仅适用于One-Shot事务 |





# 业务层

解决思路有：XA(异构系统)，TCC，Saga，基于本地消息的分布式事务，基于事务消息的分布式事务

具体的产品有：seata， hmily， byetcc， easytransaction,XA-JTA(atomikos,bitronix,narayana) ,JOTM, BTM, MSDTC



## 同构与异构系统

同构：MySQL Cluster NDB，VoltDB

异构：MySQL和MQ，MySQL和Redis

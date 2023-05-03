---
title: Java应用组成集群的方式探索
date: 2021-12-20 21:49:26
tags: distributed system
categories:
  - 分布式系统
  - 应用集群
---



# 概述

本文主要讨论**分布式业务系统**(有别于分布式存储系统)中的组建集群方式，系统高可用的方式是节点冗余，而节点冗余本身并不需要保证节点互相通信，常用的方式是节点注册到注册中心，也即节点是无状态的，这是最简单的分布式模型，集群模式是在此模型上加了稍许复杂度，但是对于业务系统想要组成集群的话，需要集群间通信。本文主要探讨分布式业务系统组成集群的方法，而不是探讨集群模式下的具体功能设计(如分片，Workqueue，Sactter/Gather, Scale out等功能)。这里**集群定义**我认为需要**满足两个基本条件**：

1. **必须有membership change的能力。**节点增加，移除，宕机对集群可感知。
2. **必须有协调机制。**这里可以认为是Leader Select或者Primary Select能力，当然Amazon的Dynamo是通过Gossip实现的P2P系统并没有Leader节点。

满足上述集群定义则系统会满足：

**高可用 ->  复制(Replication)  ->  一致性(Consistency)  ->  共识(Consensus)**

系统间通信方式有rpc，mq，系统体系结构有单机，多机（主从，对等，集群），而Java应用组成集群方式总结如下：

1. 借助单机/分布式存储：etcd/zookeeper/nacos/consul/[doozerd](https://github.com/ha/doozerd)/mysql/[MFS](https://moosefs.com/)/NFS
2. 借助中间件/框架：Hazelcast，Akka，[Serf](https://www.serf.io/)(Gossip)，[**JGroups**](http://www.jgroups.org/overview.html) , [**Erlang/OTP(非Java)**](https://www.erlang.org/doc/reference_manual/distributed.html)
3. 借助协议：raft，gossip，zab，paxos。需要利用开源实现来构建系统。



# 借助存储

借助存储，一般会采用etcd/zk这种方式较多，可以非常方便实现Leader选举，任务分发，任务调度，分布式锁，分布式队列等功能，并且membership change可以检测到。当然用Redis也可以实现类似功能，但是redis实现membership change需要额外开发，本身并不支持。

# 借助中间件/框架

Hazelcast也可以实现Leader选举，分布式弹性计算，分布式内存Map/List/Set等功能，应用系统借助嵌入式hazelcast便可以方便集成。或者Hazelcast竞品[Atomix](https://atomix.io/docs/latest/getting-started/), [Apache Ignite](https://ignite.apache.org/)

Akka的[Cluster](https://doc.akka.io/docs/akka/current/typed/cluster.html)，[Cluster Singleton](https://doc.akka.io/docs/akka/current/typed/cluster-singleton.html), [Cluster Sharding](https://doc.akka.io/docs/akka/current/typed/cluster-sharding.html)，[Distributed Data](https://doc.akka.io/docs/akka/current/typed/distributed-data.html)功能非常强大，非常适合节点组建集群，用于解决集群单例，分片等问题。

JGroups是Java的组通信框架，也可以实现集群成员变更，其官方有基于[**HSQLDB+JGroup**](http://www.jgroups.org/hsqldbr.html)的例子，[**任务分发系统**](http://www.jgroups.org/taskdistribution.html),  [**ReplicationCache**](http://www.jgroups.org/replcache.html)。

# 借助协议

借助协议实现较为复杂，但是灵活性最大。需要引入协议的实现库，并且自己构建业务系统，常用的Raft Plus的方式，Raft+业务系统，当然可以实现Raft协议本身的功能，比如选举，集群成员变更，具体取决于协议的实现，比如协议是否实现节点通信以及日志存储等功能，如etcd-raft用起来比较难，但是既然用了etcd-raft，为什么不直接用etcd呢？其他存储层Raft Plus方案还有，raft+redis=[redisraft](https://github.com/RedisLabs/redisraft)，raft+rocksdb=tikv，raft+sqllite=[rqlite](https://github.com/rqlite/rqlite)，[hashicorp-raft](https://github.com/hashicorp/raft)+boltdb=consul，mysql+paxos= MGR，这里只是参考，相比较存储层，在业务层用raft会简单一些。这里推荐Java的raft实现蚂蚁金服的[sofa-jraft](https://www.sofastack.tech/projects/sofa-jraft/overview/)。

# 总结

本文探讨了业务层组建集群方式，业务层组建集群相比较存储层组建集群要简单，因为存储层往往需要分布式事务+数据复制带来一致性的这些语义，而业务层相对来说弱化了这些语义，由下层基础设施保证。我认为相比较而言业务层组建集群方式以下更优：借助存储方案是etcd/zk(curator)，借助中间件/框架是Akka和Hazelcast，借助协议是Raft Plus.

# 参考

- hazelcast和ignite对比：https://hazelcast.com/resources/hazelcast-vs-gridgain/
- 《分布式系统设计》- Brendan Burns [designing-distributed-systems](https://github.com/brendandburns/designing-distributed-systems)
- 《云计算架构设计模式》- Microsoft https://docs.microsoft.com/zh-cn/azure/architecture/patterns/
- 《Akka应用模式-分布式应用程序设计实践指南》- Michael Nash
- 《高伸缩性系统 Erlang/OTP大型分布式容错设计》- Francesco Cesar
- 分布式系统研究泛型模板 https://xiaozhiliaoo.github.io/2021/04/24/distributed-systems-research-paradigm/

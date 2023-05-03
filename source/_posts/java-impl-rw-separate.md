---
title: Java应用层实现MySQL读写分离
date: 2022-07-02 12:49:00
tags:
  - 读写分离
  - 应用设计
categories:
  - 数据库
---

# 设计

实现读写分离一般有4种机制：

1. 应用层实现（借助Spring的[AbstractRoutingDataSource](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/jdbc/datasource/lookup/AbstractRoutingDataSource.html)）。
2. 框架层（如[sharding-jdbc](https://shardingsphere.apache.org/document/4.1.0/cn/manual/sharding-jdbc/)，[tddl](https://github.com/alibaba/tb_tddl)）。 
3. 中间件层（如[mycat](http://www.mycat.org.cn/)）。
4. 数据库/分布式存储本身支持，如分布式数据库或newSQL，如[MySQL Cluster](https://en.wikipedia.org/wiki/MySQL_Cluster)，[OceanBase](https://www.oceanbase.com/)，Redis Cluster等。

本文主要分析应用层实现读写分离思路。读写分离实现思路：配置多个读写数据源，通过当前DAO层请求方法判断当前应该请求的数据源类型，如果是读方法，那么请求读库，如果是写方法，那么请求写库，如果一个方法既有读和写，那么写后读全部走写库，从而避免主从延迟带来数据一致问题。

应用层实现读写分离/垂直分库分表是简单的事情，但是应用层实现水平分库分表却是一个复杂问题，我曾经的项目是先遇到读写分离问题，于是自己应用层实现，然后遇到了分库分表问题，采用了sharding-jdbc的方案，该方案即解决了读写分离，也解决了分库分表。

# 实现

## 配置多数据源

配置包含读写的数据源，主库命名**ds-write**，写库命名**ds-read**.

## 判断当前读写方法

通过Spring的AOP拦截DAO层请求方法，如下：

```java
@Aspect
@Order(1)
@Component
public class DataSourceAop {
    @Pointcut("execution(* com.dao..*.*(..))")
    public void changeDataSource() {
    }

    @Before("changeDataSource()")
    public void changeDataSource(JoinPoint joinPoint) {
        //切换主库或者从库
        DataSourceInterceptor.changeDataSource(joinPoint);
    }

   
    @After("changeDataSource()")
    public void clearDataSource(JoinPoint point) {
        //方法离开DAO层要清除当前数据源，但是不会清除使用过的是主还是从
        DataSourceInterceptor.removeDataSource(point);
    }
```



## 切换主库的实现

```java
public class DataSourceInterceptor {
    //指定只读的方法(人为指定，如selectXXX，findXXX，getXXX)
    private static List<String> READ_METHODS = Lists.newArrayList("selectXXX");
    //标识当前线程是否使用过主库
    private static ThreadLocal<Boolean> masterFlag = new ThreadLocal<Boolean>();
    
    public static void changeDataSource(JoinPoint jp) {
        String dataSource = "ds-write";
        //当前线程如果写过主库，那么后面的请求均走主库
        String methodName = jp.getSignature().getName();
        if (!isMasterAccess() && READ_METHODS.contains(methodName)) {
            dataSource = "ds-read";
        } else {
            setMasterFlag(true);
        };
        //设置最新的数据源
        DataSourcetHolder.setDataSource(dataSource);
    }
    
    public static boolean isMasterAccess() {
        return masterFlag.get() == null ? false : masterFlag.get();
    }
    
    public static void removeDataSource(JoinPoint jp) {
        DataSourcetHolder.clearDataCourse();
    }
}
```



## 设置最新的数据源

设置最新的数据源到**ThreadLocal**里面

```java
//用于存储数据源的名字，以方便获取当前数据源进行切换。
public class DataSourcetHolder {
    private static final ThreadLocal<String> holder = new ThreadLocal<String>();

    public static void setDataSource(String dsName) {
        holder.set(dsName);
    }

    public static String currentDataSource() {
        return holder.get();
    }

    public static void clearDataCourse() {
        holder.remove();
    }
}
```

## 动态数据源切换

动态数据源借助Spring的**AbstractRoutingDataSource**类来实现切换：

```java
public class DynamicDataSource extends AbstractRoutingDataSource {

	@Override
	protected Object determineCurrentLookupKey() {
        //获取最新的数据源名字
		return DataSourcetHolder.currentDataSource();
	}
}
```

# 总结

## 复制与延迟

副本冗余的主从复制一定会带来数据一致性问题，由于不同系统的复制模型不同，所以不同系统保证的一致性级别不同。MySQL默认复制是异步复制，所以数据一致性问题是典型的最终一致性，一致性窗口时间没有确定性保证，而强制写后读走主库，属于会话Sticky，类似于一种会话一致性（非严格，因为读别人写不一定最新）或者读自己写一致性，但是在ShardingJDBC中，程序开始就设置HintManager.setMasterRouteOnly()，那么整个会话都走主库，所以保证会话一致性。由于MySQL异步复制由于采用从节点拉取主节点binlog，而不是主节点主动推送复制数据，所以从库会挂了而主库依旧不知道。我曾经在测试环境遇到从库挂了好几天的[情况](https://blog.51cto.com/thinklili/2591474)，主库依旧在工作。所以一致性几乎发生故障情况下不可保证。所以MySQL异步复制下，既有主库也有从库请求，一般是写后读全部查主库。但是如果MySQL配置的是全同步/半同步复制，那么数据一致性问题就会减弱，但是会导致严重性能问题。这是典型的PACELC的权衡。在没有发生网络分区或其他故障情况下，延迟和一致性的权衡。

复制会带来一致性问题，不同复制模型带来的一致性问题不同，而一致性问题通过和顺序存在关系。复制，一致性，顺序，共识存在深刻的联系。理解这些关系，对理解系统限制会有帮助。

## 分库，分表，读写分离，水平垂直

对于一个数据表的设计，需要考虑是否分库，是否分表，是否读写分离，水平还是垂直。而每种选择意味着不同的设计，总共有16种可能性。分库(Y/N) **×** 分表(Y/N) **×** 读写分离(Y/N) **×** 水平或垂直 = 16种。但是如果读写分离是必须的，那么其实有8种选择。而8种选择里面，垂直是较少的，所以大部分是水平的，其实就剩下了4种，实际需要根据不同情况进行选择。

# 参考

1. MySQL半同步复制（ *https://dev.mysql.com/doc/refman/8.0/en/replication-semisync.html* ）
1. Jepsen一致性模型（ *https://jepsen.io/consistency* ）

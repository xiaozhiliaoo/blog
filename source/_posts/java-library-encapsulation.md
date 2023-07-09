---
title: Java类库封装的三步
date: 2023-07-09 20:26:50
tags:
  - 组件设计
  - 框架设计
categories:
  - Java类库设计
---

我觉得最重要的要有**一致性**的理念，也就是灵魂。当然也可以在实现完之后提炼一个理念。

总共分为三步：1. 提炼出一个设计理念 2. 设计实现  3.测试


# 设计理念

比如有：使用简单，配置灵活，扩展性好，测试完备，具备内部监控。

# 设计实现

## 1.通用实现的结构

需要给业务层提供通用类库，该以怎么样的方式提供？通常有以下几种方式：

1. 类似于apache common，JDK这种模式，应用层调用库。
1. 类似于IOC/框架模式/模板(XXXTemplate)/策略(回调)模式，框架调用应用层代码。典型的如JDBCTemplate或SPI模式。
1. 类似于普通Spring模式，提供库，并且暴露配置且提供默认配置，由应用层自定义设置，业务层直接使用。
2. 类似于Spring boot stater+auto-configuration这种模式。

## 2.通过JMX暴露操作和属性

使用Spring的@ManagedResource或者注册到MBeanServer中。

或者纯JDK的注册到MBeanServer。

## 3.通过自定义Spring Boot Actuator endpoint和InfoContributor监控和交互

1. 通过Springboot Actuator  [InfoContributor](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/actuate/info/InfoContributor.html) 接口来暴露endpoint info信息。
2. 通过自定义的Endpoint来内部信息。



# 测试

没有测试的类库质量会较低。

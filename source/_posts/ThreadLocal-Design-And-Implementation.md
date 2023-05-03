---
title: ThreadLocal设计,实现,使用注意
date: 2020-11-15 03:39:59
tags: java.lang
categories:
  - JDK源码
  - Java核心
---



# 概述

线程局部变量是避免多线程读取共享变量造成竞争的一种机制，每个线程只能看到自己的私有变量，这就避免了锁竞争问题。在Java中，使用ThreadLocal可以实现该机制。



# 结构

在Java的ThreadLocal中，一个线程拥有多个ThreadLocal，每个ThreadLocal的变量存储在包级可见的内部静态类ThreadLocalMap中，ThreadLocalMap的Key是用WeakReference包装的ThreadLocal，Value则是强引用普通变量，每个ThreadLocal及其变量以KV形式存储在ThreadLocalMap中，而ThreadLocalMap并没有实现Map接口，而是自己实现了类似Map的功能。当前线程不在活跃的时候，垃圾收集器回自动回收ThreadLocal。即使内部细节非常多，但是ThreadLocal暴露给客户端的API确是非常简单，核心方法仅有initialValue，set，get，remove方法，这是经过多次改进后的设计。下图是结构图：

单一线程：

<img src="/images/ThreadLocalMap.png" style="zoom:75%;" />



多线程：

![](/images/ThreadLocalMultiThread.png)



从图中得出结论：

多个线程使用同一个ThreadLocal时候，每个线程会在内部创建一个自己的ThreadLocalMap. Thread:ThreadLocal:ThreadLocalMap=多:一:多

一个线程使用多个ThreadLocal时候，一个线程创建了多个 ThreadLocalMap. Thread:ThreadLocal:ThreadLocalMap=一:多:一

所以ThreadLocalMap数量和线程数有关。ThreadLocal是和一个领域或者业务有关。



下图是类图：

![](/images/ThreadLocal.png)



# 实现







# API演进









# 实战







# 使用注意

1 由于每个线程的可以有多个ThreadLocal，每个ThreadLocal是唯一的，所以定义ThreadLocal时候需要定义成static final，并且初始化一个值。



2 当已经给ThreadLocal设置值后，最好不需要时候主动remove，防止线程变量泄漏。



3  当有父子线程需要共享传递值的时候，需要使用ThreadLocal的子类InheritableThreadLocal.



4 当使用线程池更需要注意由于线程的可复用性，所以可能导致复用的线程拥有之前任务所传递的ThreadLocal局部变量，所以要在任务结束之后finallyremove该Worker的局部变量。



5 内存泄漏和变量泄漏问题。
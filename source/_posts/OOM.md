---
title: java.lang.OutOfMemoryError内存溢出
date: 2020-08-16 21:51:03
tags:
  - 内存溢出
  - 内存泄露
categories:
  - JVM
---



对这个问题的深入理解，取决于对GC，内存本身的理解。终极问题。

内存，GC，

内存溢出指的是程序需要内存超出系统所有的内存，如果是正常情况调大jvm内存即可，如果是

Java内存区域分为这么几个区域

堆区：老年代，新生代

非堆：metaspace



FullGC之后空间不足，内存没有回收。





Java OOM情况有以下几种，



### java heap space

原因：1 应用需要更多对空间  2    内存泄漏（类加载器内存泄露，ThreadLocal 不remove内存泄漏，和线程池一起使用会泄漏）

举例：

解决方案：

这种情况属于fullgc之后，堆空间不足，内存泄漏是内存溢出的一个原因，但是内存泄漏不一定导致内存溢出。



### GC Overhead limit exceeded

频繁FullGC导致该错误



###  Permgen space

Java7 持久代空间不足



###  Metaspace

Java8

1 应用加载类太多了

2 classloader内存泄漏

元空间不足，java8之后才会有



### Unable to create new native thread

本地线程创建数量超过操作系统的线程数



### Out of swap space？

交换区



### Compressed class space





### Requested array size exceeds VM limit





### reason stack_trace_with_native_method





### 参考

1.  Oracle官网 [Understand the OutOfMemoryError Exception](https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/memleaks002.html#CIHHJDJE)
2.  Plumbr The 8 symptoms that surface [outofmemoryerror](https://plumbr.io/outofmemoryerror)
3.  Wikipedia [Out of memory](https://en.wikipedia.org/wiki/Out_of_memory)
4.   Ponnam Parhar的slide  [Slides](https://www.slideshare.net/PoonamBajaj5/get-rid-of-outofmemoryerror-messages)  [Video](https://www.youtube.com/watch?v=iixQAYnBnJw)


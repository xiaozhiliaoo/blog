---
title: Java集合框架(3)-HashMap设计与实现
date: 2020-11-14 21:01:10
tags: 
  - java.util.*
  - java collection framework
categories:
  - JDK源码
  - Java集合框架
---



# 序言

​          HashMap在面试中被频繁问到，从我入行(2015年)问到了现在，我一直思考，就一个Map的实现有什么好问的，曾经对问我HashMap的面试官忍不住吐槽：难道你们没别的问的了？但是不可避免这个问题的出现频率，因为这体现你的“Java基础”。于是为了回答好这个问题，我从网上看了很多资料，从此面试时候不在被HashMap所难倒，但是我好像除了应付面试，从HashMap并没有学到什么东西，有一天，我下定决心，真正地重新学习HashMap的实现，从此好像发现了宝藏一样，对我的代码水平提高也很有帮助，从最初的迷惑，不屑，到现在对HashMap的喜欢，也是见证自己对技术从实用主义到真正渴望理解的一个提高，也是从浮躁到沉淀的一个见证。所以这篇文章总结了自己对HashMap的设计与实现的认识。



# 概述

​          HashMap作为最经典的Map接口实现，内部实现细节非常复杂，但是设计本身实现却是一致的，没有脱离Map接口和整个集合框架带给我们的抽象。**Node**和**TreeNode**作为**Map.Entry**的实现类，代表了**HashMap**内部的不同类型**Entry**， **KeySet，Values，EntrySet**分别作为Map的key,value，Entry的视图. 而**HashIterator，KeyInterator，ValueIterator，EntryIterator**分别作为KeySet，Values，EntrySet的迭代器实现，用于遍历Map，而**HashMapSpliterator，KeySpliterator，ValueSpliterator，EntrySpliterator**作为HashMap支持流式编程的Spliterator的实现。虽然看着类很多，但是抽象围绕**迭代器，分割器，视图，Entry**去实现的。由此可以得知，支持HashMap的实现由这些基本抽象组成。在接下来结构中，可以体现这些细节。



# 结构

HashMap的内部结构较多，但是并不难以理解。

![](/images/HashMap.png)









# HashMap的API





# HashMap的实现





# 启示
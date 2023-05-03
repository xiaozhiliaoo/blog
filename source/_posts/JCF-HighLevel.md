---
title: Java集合框架(1)-接口定义类型
date: 2020-11-09 01:19:19
tags: 
  - java.util.*
  - java collection framework
categories:
  - JDK源码
  - Java集合框架
---



# 序言

集合框架是任何语言的技术体现，是语言的综合使用的类库，大部分工作可以用集合完成，但是单独的看每一个集合实现类难以对集合框架产生一个宏观认识，所以需要从高层角度来看集合技术，本系列将分析集合框架的设计与实现。



集合设计包括**接口，实现和算法**三大核心功能。接口包括类型接口和迭代器接口，类型接口是List，Set，Map，Queue等接口，而迭代器接口包括顺序迭代器和分割器，实现包括骨架实现，视图实现，数据结构实现，骨架实现就是AbstractList，AbstractSet，AbstractMap,AbstractQueue等实现，视图实现比如ArrayList的SubList，HashMap的KeySet，Values和EntrySet，而数据结构实现是特定的类型实现比如List有ArrayList和LinkedList，算法主要有排序，查找，shuffle 等，这三个功能构成了集合的设计核心。



使用集合类型有非常多的好处：

1

2

3







# 结构

集合中最重要的是接口，接口定义了数据类型，抽象类实现了接口，而具体集合类实现了真正的类型。接下来会分析每种数据结构类型接口方法，根本特征以及不同类型之间的真正区别。

### 基本接口

<img src="/images/JCF-Base.png" style="zoom:67%;" />

集合的基本组成是元素，元素即对象。这些元素本身是普通对象，但是被集合框架管理起来就具有鲜明特点，如可以迭代，可以被分割，可以比较大小排序，而正是这些基础的能力构成了集合最核心的三大接口：**Iterator，Spliterator，Comparator**.

**Iterator**提供了种不需要知道集合实现就能遍历的能力,也是经典的设计模式。

**Spliterator**提供了分割集合的能力，在并行遍历中常用。

**Comparator**提供了元素比较大小的能力，在排序中常用。



### Collection接口

Collection是JCF的顶级接口，该接口定义了集合的基本操作，其中分为查询，修改，块操作，基本对象操作。

```java
//查询
int size();
boolean isEmpty();
boolean contains(Object o);
Iterator<E> iterator();
Object[] toArray();
<T> T[] toArray(T[] a);
//修改，在List/Set/Queue中也会重新定义这些方法，因为这些方法在这些接口中有了新的含义，异常也和Collection
//add接口异常也不一样，因为add对于不同接口意思不同，，如List.add只是添加元素，Set.add添加不同元素，Queue.add
//如果超过了Queue长度，会抛出异常。
boolean add(E e);
boolean remove(Object o);
//块操作
boolean containsAll(Collection<?> c);
boolean addAll(Collection<? extends E> c);
boolean removeAll(Collection<?> c);
boolean retainAll(Collection<?> c);
void clear();
//基本对象操作
boolean equals(Object o);
int hashCode();
```

这些操作定义了Collection基本操作，也是契约。而这些子接口Set，List，Queue有些重新定义了Collection接口方法，有些则没有，因为不同接口的含义不同。比如List，Set，Queue都重新定义了add方法，但是List，Set定义size()方法，Queue却没有定义，因为我认为size方法在List和Set(cardinality)含义不同，但是Queue的size含义和Collection一样。这种**父接口定义方法，在子接口重新定义方法**的技巧在JCF中广泛使用。



### List接口

<img src="/images/List-Impl.png" style="zoom:67%;" />



List是一种Collection，但是Collection不一样，List支持index访问，所以List接口新加了关于index的方法，index是List最重要的抽象之一.同时List也把Collection中的方法重新定义了下，

```java
void add(int index, E element)
boolean addAll(int index, Collection<? extends E> c);
E get(int index);
int indexOf(Object o);
int lastIndexOf(Object o);
ListIterator<E> listIterator();
ListIterator<E> listIterator(int index);
E remove(int index);
E set(int index, E element);
List<E> subList(int fromIndex, int toIndex);
```



### Set接口

<img src="/images/set-impl.jpg" style="zoom:67%;" />

Set接口将Collection方法几乎全部定义了遍，因为Set具有数学意义上集合的含义，所以集合操作需要新定义一套契约，用来表达Set的不同于Collection之处。



### Queue接口

![](/images/Queue-Impl.png )

Queue也是一种Collection，但是接口中并没有新加任何方法，只是把Collection接口方法重新定义了下，因为和Collection内涵不一样。但是仅仅重新定义了add方法，其他方法并没有重新定义，因为add方法在Queue满的时候会抛出异常。这和List，Set，Collection均不一样。

```java
//入队，如果队列满抛出IllegalStateException异常
boolean add(E e);
//入队，如果队列满返回false
boolean offer(E e);
//出队队头元素，没有元素则抛出NoSuchElementException异常
E remove();
//出队队头元素，没有元素则返回false
E poll();
//查看队头元素，没有元素则抛出NoSuchElementException异常
E element();
//查看队头元素，没有元素则返回false
E peek();
```

队列方法比较对称，add/remove，offer/poll，element/peek，这也是API对称设计的范例。





### Deque接口

![](/images/Deque-Impl.png)



### Map接口

<img src="/images/Map-Impl.png" style="zoom:67%;" />



Map接口里面的Map.Entry

map接口







以上便是集合框架最重要的接口和实现(不包括并发集合，并发集合将在并发中分析)了，我们接下来分析将会围绕抽象实现和具体集合类而展开



# 参考

https://docs.oracle.com/javase/tutorial/collections/




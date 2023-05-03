---
title: CRUD Boy和API Caller的怪象
date: 2021-01-01 18:40:35
tags:
  - 代码设计杂谈
categories:
  - 杂谈
---



CRUD，API Caller，Copy Paste 在业界被认为很低级工作，和low的技能(更多是自黑)。Spring作者Rod Johnson曾用一个比喻来说明问题，多瘤程序员: 学会一门技术但是留下来很多伤疤。经常认为和带着这样想法工作会降低个人生产力和对工作技术的敏感度。

# CRUD Boy

​        CRUD指的是对存储层的增删改查和业务层的逻辑计算。毕竟业务逻辑就是存储和计算。低级之处在于程序开发仅仅是对数据库数据的事务脚本操作，但是业务系统设计，在小型项目中CRUD可以Hold住复杂度，但是当业务系统复杂起来时候，事务脚本将带来维护性和扩展性问题，此时系统的各种业务逻辑和组件将会变得非常复杂且无趣。解决这个办法在于**良好的业务抽象**和概念**一致性的业务接口**，此时CRUD将不再是事务脚本，而更类似于OOD，而随着业务演进，可能会拆分微服务，这时候如果没有从CRUD泥潭出来，新建的微服务还是会重复事务脚本的老路。而业界有更好的业务设计方法，是**领域驱动设计**，将业务设计和技术设计结合起来，可以借鉴其思想，有句话说的比较好DDD is OOD done right.

​       同时CRUD代码也不是没有技术含量的，CRUD代码也需要扩展性，维护性，可读性，文档注释，可测试性，不断重构达到整洁代码的水平，而这些任意一个工程实践，都会对既有团队带来编码习惯带来改变和编程水平的提高。所以CRUD没有技术含量，是更多把CRUD当做业务需求翻译机，产品说加你就加，而不是业务需求的解释器，用技术语言来设计业务。

​       

# API Caller

API Caller是只会简单用类库和调第三方接口，没有完全理解调用方。这种透明性对业务开发进度有帮助，但是对于个人技术成长却是弊大于利。比较典型的例子是你用别人封装好的Redis接口查数据，会错以为自己会Redis，用厂商提供好的mq接口开发，发送几条消息，消费几条消息就认为自己用过mq，从而在实际工作中变成了只会调用API。在Java类库中，NIO代码冗余且复杂，学习NIO API本身就是对NIO的学习，但是写完就忘，下次还要重新学习，但是下次的学习或许没有从更深概念理解NIO，而是重新学了一遍NIO API使用代码，这样比较浪费时间。

对于高质量的程序，绝大部分是注重API设计质量的，这不仅关系到API使用，还有API的理解性上，好的API本身就会抽象最核心的概念给开发者，模块间通信也会精心设计API。在JAVA世界中，集合框架和并发包可以说是对API契约和设计的经典案例，任何学习API设计的都可以从此开始研究，光看集合提供的接口，就能够收获非常多的概念和抽象。同时高质量API的文档也能够加深对技术的理解。当然API的实现也很重要，但是重要程度不如API本身。关于这方面可以参考：[集合接口](https://xiaozhiliaoo.github.io/2020/11/09/JCF-HighLevel/)

我们以Guava Cache来分析从API中能获得什么？

```java
//LoadingCache的父接口Cache也包含非常多的方法，这里不做探讨。
public interface LoadingCache<K, V> extends Cache<K, V>, Function<K, V> { 
      V get(K key) throws ExecutionException;
      V getUnchecked(K key);
      ImmutableMap<K, V> getAll(Iterable<? extends K> keys) throws ExecutionException;
        /**
       * Loads a new value for key {@code key}, possibly asynchronously. While the new value is loading
       * the previous value (if any) will continue to be returned by {@code get(key)} unless it is
       * evicted. If the new value is loaded successfully it will replace the previous value in the
       * cache; if an exception is thrown while refreshing the previous value will remain, <i>and the
       * exception will be logged (using {@link java.util.logging.Logger}) and swallowed</i>.
       *
       * <p>Caches loaded by a {@link CacheLoader} will call {@link CacheLoader#reload} if the cache
       * currently contains a value for {@code key}, and {@link CacheLoader#load} otherwise. Loading is
       * asynchronous only if {@link CacheLoader#reload} was overridden with an asynchronous
       * implementation.
       *
       * <p>Returns without doing anything if another thread is currently loading the value for {@code
       * key}. If the cache loader associated with this cache performs refresh asynchronously then this
       * method may return before refresh completes.
       *
       * @since 11.0
       */
      void refresh(K key);
      /**
       * Returns a view of the entries stored in this cache as a thread-safe map. Modifications made to
       * the map directly affect the cache.
       *
       * <p>Iterators from the returned map are at least <i>weakly consistent</i>: they are safe for
       * concurrent use, but if the cache is modified (including by eviction) after the iterator is
       * created, it is undefined which of the changes (if any) will be reflected in that iterator.
       */
      ConcurrentMap<K, V> asMap();
}
```



先看**get**方法，抛出了ExecutionException异常，这个异常定义在并发包java.util.concurrent下，所以可以猜测get时候会不会和并发，多线程执行有关.否则不可能无缘无故抛出这么个异常。事实证明猜测是对的，Guava对于[Interruption](https://github.com/google/guava/wiki/CachesExplained#interruption)的处理很多设计决策。

**getUnchecked**同样是获取v方法，没有抛出任何异常，方法名是获取非受检异常，可以看出获取key的时候，一定会报错，但是提供了更加灵活的异常处理机制，而这些知识，就需要对受检异常和非受检异常有清晰的认识才能设计出这样的API，否则是不会想到这一层的。

**getAll**这个接口设计很有意思，传参是Iterable，足够看到其通用和扩展性，但是返回确是不可变的Map，看到这里，是不是觉得比较有趣呢？可以质疑为什么不用List接口呢？当然使用的时候传入Key List是可以的，但是如果你不理解Iterable的接口，你这段代码很有可能需要百度demo才能写出来，下次遇到同样的问题还是没有任何进步，成为了API Caller。

**refresh**从方法签名看不出什么，但是API文档注释非常详细，足够了解了。

**asMap** 是缓存的视图，但是修改缓存视图会导致底层缓存被修改，并且用的是并发的Map接口，此时几乎可以得出结论，缓存大概率会并发读写的，所以benchmark时候，并发读写能力一定是一个点。此时你对ConcurrentMap操作时候就需要清晰地了解ConcurrentMap的特性，并发修改时候遍历等问题。如果你希望业务层缓存只能用来读，而缓存层做缓存更新的话，你可以将asMap包装成不可变的Map. 当转换成Map时候，疑问在于关于Cache的契约是否就会被打破了？比如get时候load数据。

可以看到，还没有看LoadingCache的实现，我们就可以很多，看完核心接口，在辅以文档，可以说对Cache Design和Decision有最基本的认识了，缓存和高性能有着千丝万缕的关系，需要深入到边边角角，既能从高层知道如何设计一个Cache，也能从底层知道如何实现一个Cache，否则在工程中可能因为一个参数配置就会导致性能问题。虽然以上方法在使用起来非常简单，但是合理的理解其设计和抽象对使用产生很大帮助，对不同API也能触类旁通，也可以提高自己设计API的水平，从此脱离API Caller的窘境，成为一名API Designer. 

API Caller还有一个非常典型的例子是线程池的使用。API Caller还有特点不喜欢看API文档，甚至不知道哪里看API文档。

个人比较喜欢的学习技术方法是：无论如何先看一遍官方文档，学有余力则看一遍API文档，很感兴趣则可以入手源码。



# Copy Paste

粘贴复制本身其实没有什么问题，可以提供编程效率，但是由于复制带来的**代码重复**问题较为严重。因为这是时空级别的重复，虽然重复的概念很简单，但是衍生带来的，维护性，可读性，耦合性，内聚性问题，牵一发而不知道影响面，会极大降低代码仓库质量和Bug数量。如果说技术债最严重的问题，我觉得是重复代码问题。通过良好的抽象和封装，以及子函数，状态聚合，行为聚合等编程手段，会减少重复问题。





# 技术方案与实现的不一致性

技术方案更偏向于架构，而实现更偏向于代码。有些技术方案涉及到编程(比如redis使用)，有些则无需（比如nginx负载均衡和容器化）这两者在某些程度并不是一致的。有些时候技术方案提出者并不是实现者，即使是，也有可能出现方案很牛逼，但是编码能力有限会导致的实现不好的现象。这点有一个例子，比如架构上引入缓存作为一个高层次的组件，但是缓存具体选型和实现上，则会出现分歧，用ConcurrentHashMap还是Guava Cache呢？这两者对于代码实现的复杂度不同。在实现的时候，又会面临如何封装，代码包组织，如何抽象的编程等非常细节问题，如果使用了Guava Cache，则会不会沦为API Caller的窘境呢？



# 总结

crud boy，api caller，copy paste在开发业务时候会带来巨大便利，但是使用和理解不好也会造成非常多技术债和坑，这对个人成长帮助有限，会带来**我不断在学习**的假象，实际难逃轮回，凡所有相，皆是虚妄，若见诸相非相，即见如来。多花些时间研究API(包括优质和劣质)是有帮助的，要对业内“**忘记了，百度下就能知道了**”如此言论保持怀疑，他会使你真正成为API Caller的。你我都在路上！


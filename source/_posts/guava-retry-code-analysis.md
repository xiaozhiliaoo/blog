---
title: guava-retry源码分析
date: 2020-08-15 14:50:19
tags:
  - guava-retry
categories:
  - 源码分析
---



guava-retry是扩展guava的一个重试库。



### 一  问题(Question)

在系统设计的时候，重试作为系统容错方法，被广泛使用在云化系统，微服务系统，并以模式形式记录在 [azure cloud design pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/retry )从而使得系统变得更加健壮和弹性(resilient)，同时和熔断，限流等策略结合起来，充分保证系统可靠性。但是如何设计一个可复用，可扩展的重试库，需要先了解重试的设计问题。业界给出的答案有：[guava-retry](https://github.com/rholder/guava-retrying)，[Spring Retry](https://mvnrepository.com/artifact/org.springframework.retry/spring-retry) ，[Resilience4j](https://mvnrepository.com/artifact/io.github.resilience4j/resilience4j-retry) ，本文主要对guava-retry进行分析。



### 二  设计(Design)

重试的设计问题有以下几个方面：

- 1   什么时候开始重试？ 异常和错误或不满足预期值。

- 2   重试策略是什么？ 重试策略可以具体划分一下三个方面：

  ​          2.1 基于次数(空间)还是基于时间，还是两者结合起来

  ​          2.2 重试间隔策略是什么？是等待指定时间后重试，还是无限重试，还是指数回退呢

-  3   什么时候停止重试？



### 三 抽象和分解(Abstract and Decomposing)

通过对问题的理解，可以抽象出核心概念和隐喻解决这个问题。来看看guava-retry的抽象和解决之道。

1. 执行过程抽象成Callable对象，执行时间控制通过TimeLimiter来管理。

2. 将通过对返回结果封装成Attempt对象，来表达结果是否有异常，获取该结果已经重试次数，距离第一次重试耗费多久。

3. 将重试条件组合成Predicate对象。

4. 等待策略WaitStrategy获取等待时间，阻塞策略BlockStrategy用于重试间隔的阻塞，停止策略StopStrategy。以及提供了默认策略实现的WaitStrategies工厂，BlockStrategys工厂，StopStrategys工厂。

5. RetryListener监听器，监听每次重试时候的动作。

6. RetryerBuilder用于构造Retryer，Retryer将条件，过程，策略通过call(Callable<V> callable)方法组合起来，来完成整个重试机制的实现。

   

### 四 类图(Class Diagram)

![类图](/images/guava-retry.png)



### 五 核心流程(Core process)



```java
//Retryer类的核心流程call方法中，将RetryerBuilder中的等待条件，执行过程(指定时间执行完成)，等待策略，阻塞策略，
//停止策略整合起来完成重试机制的设计。
public V call(Callable<V> callable) throws ExecutionException, RetryException {
    long startTime = System.nanoTime();
    //for循环中不断重试，并通过attemptNumber来记录重试次数
    for (int attemptNumber = 1; ; attemptNumber++) {
        Attempt<V> attempt;
        try {
            //指定时间内返回结果
            V result = attemptTimeLimiter.call(callable);
            //正常返回结果封装成ResultAttempt对象，并且记录真实结果，重试吃啥，距离第一次返回结果的时间间隔
            attempt = new ResultAttempt<V>(result, attemptNumber, TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startTime));
        } catch (Throwable t) {
            //异常返回结果封装成ExceptionAttempt对象
            attempt = new ExceptionAttempt<V>(t, attemptNumber, TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startTime));
        }
        //监听器回调Attempt结果
        for (RetryListener listener : listeners) {
            listener.onRetry(attempt);
        }
        //各种重试条件(结果预期，抛出异常，状态码非200等判断)组合Predicate判断，是否需要重试
        if (!rejectionPredicate.apply(attempt)) {
            //不需要重试直接返回真实结果
            return attempt.get();
        }
        //需要重试时候判断此次是否停止重试
        if (stopStrategy.shouldStop(attempt)) {
            //停止重试时候，说明正确返回值还没有获取，即认为重试失败，抛出重试异常，交由客户端处理
            throw new RetryException(attemptNumber, attempt);
        } else {
            //等待策略获取等待时间
            long sleepTime = waitStrategy.computeSleepTime(attempt);
            try {
                //开始等待
                blockStrategy.block(sleepTime);
            } catch (InterruptedException e) {
                //线程等待中被中断，抛出重试异常
                Thread.currentThread().interrupt();
                throw new RetryException(attemptNumber, attempt);
            }
        }
    }
}
```



### 六 总结(Summary)

#### 优点:

设计上：

1. 整个源码总共13个类，6个接口,  7个类中4个工厂类，1个异常类，2个核心类，1个监听类。抽象度比较平衡，类的层次最多两层。
2. 整个源码非常简洁，容易理解，代码重复很少，对外API也很简单容易使用。
3. guava-retry使用Builder，Template，Strategy，Factory，Facade等模式将整个流程组合起来，并且提供了扩展点以自定义策略。体现了面向接口编程原则。

实现上：

1. 使用Guava的SimpleTimeLimiter，Preconditions，Predicates。
2. 引入findbugs:jsr305注解，@Immutable，@Nonnull注解，提高可读性和设计意图。



#### 缺点：

1. 官方issue较多，回复不及时，不是很活跃。
2.  SimpleTimeLimiter类在Guava中已经没有公开构造方法了，所以使用时候会报运行时错误。
3. 虽然叫guava-retry，但是实际不是google维护的代码。
4. 单元测试不全面，有些类没有测试。
5. 代码检测不如apache标准项目多，比如pmd，checkstyle等检测。
6. 由于是个人项目，工程规范方面可借鉴的较少。
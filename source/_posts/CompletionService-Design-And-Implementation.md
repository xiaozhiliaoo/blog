---
title: CompletionService设计与实现
date: 2020-11-13 02:42:06
tags: java.util.concurrent
categories:
  - JDK源码
  - Java并发框架
---



# 序言

使用ExecutorService时候，我们只是向其中不断提交任务，然后通过Future获取get任务结果，但是有时候get需要等待，虽然可行，但是比较繁琐，可以有更好的方式，比如CompletionService实现了将完成的任务放在完成队列中，使得获取任务结果可以向队列一样通过take和poll任务结果，这样比ExecutorService更加方便。CompletionService通过ExecutorCompletionService实现，这两个实现均非常简单。



# 结构

<img src="/images/CompletionService.png" style="zoom:60%;" />

通过类图，可以看出CompletionService并没有继承ExecutorService，而是内部包含了AbstractExecutorService类，CompletionService和ExecutorService比较类似地方是都有submit方法，而CompletionService获取执行结果是根据take和poll的方式去获取。



# API





# 实现

## 任务结果排队的QueueingFuture

```java
//全部final，说明在构造函数里面会创建好这些实例变量
private final Executor executor;
private final AbstractExecutorService aes;
private final BlockingQueue<Future<V>> completionQueue;

/**
 * FutureTask extension to enqueue upon completion.
 */
private static class QueueingFuture<V> extends FutureTask<Void> {
    QueueingFuture(RunnableFuture<V> task,
                   BlockingQueue<Future<V>> completionQueue) {
        super(task, null);
        this.task = task;
        this.completionQueue = completionQueue;
    }
    private final Future<V> task;
    private final BlockingQueue<Future<V>> completionQueue;
    //FutureTask的钩子方法，用户任务结束时候的扩展，QueueingFuture继承了该方法，并将结束的
    //任务放入阻塞队列
    protected void done() { completionQueue.add(task); }
}
```



## 构造函数

```java
public ExecutorCompletionService(Executor executor) {
    if (executor == null)
        throw new NullPointerException();
    this.executor = executor;
    this.aes = (executor instanceof AbstractExecutorService) ?
        (AbstractExecutorService) executor : null;
    this.completionQueue = new LinkedBlockingQueue<Future<V>>();
}
```





```java
public ExecutorCompletionService(Executor executor,
                                 BlockingQueue<Future<V>> completionQueue) {
    if (executor == null || completionQueue == null)
        throw new NullPointerException();
    this.executor = executor;
    this.aes = (executor instanceof AbstractExecutorService) ?
        (AbstractExecutorService) executor : null;
    this.completionQueue = completionQueue;
}
```



## 提交任务submit

提交任务和AbstractExecutorService类似，只不过提交的是返回结果排队的QueueingFuture.

```java
public Future<V> submit(Callable<V> task) {
    if (task == null) throw new NullPointerException();
    RunnableFuture<V> f = newTaskFor(task);
    executor.execute(new QueueingFuture<V>(f, completionQueue));
    return f;
}


public Future<V> submit(Runnable task, V result) {
        if (task == null) throw new NullPointerException();
        RunnableFuture<V> f = newTaskFor(task, result);
        executor.execute(new QueueingFuture<V>(f, completionQueue));
        return f;
}

```



## 从阻塞队列获取任务结果take，poll

```java
//如果没有完成的任务会阻塞等待
public Future<V> take() throws InterruptedException {
    return completionQueue.take();
}

//如果没有完成的任务返回null
public Future<V> poll() {
    return completionQueue.poll();
}

//带有超时的获取任务结果，任务超时，则被中断
public Future<V> poll(long timeout, TimeUnit unit)
        throws InterruptedException {
    return completionQueue.poll(timeout, unit);
}
```





# 实战
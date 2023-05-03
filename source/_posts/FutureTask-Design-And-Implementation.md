---
title: FutureTask设计与实现
date: 2020-11-11 02:14:39
tags: java.util.concurrent
categories:
  - JDK源码
  - Java并发框架
---

# 序言

FutureTask是Future和Runnable的实现，ThreadPoolExecutor在执行任务的时候，执行的是FutureTask. 传统Runnable接口实现的任务只有执行方法run，并没有任务取消，执行超时等功能，并且Runnable并没有提供任务状态的抽象，其实每个任务都是有状态的。所以FutureTask其内部将任务执行过程分为一系列状态，从而使得任务有了生命周期。在JDK中，经典的实现除了FutureTask外，还有ScheduledFutureTask. 



# 结构

![](/images/FutureTask.png)

我们可以看到它对一个普通任务支持了生命周期的方法. 从而使得任务执行有了过程的概念，而不是Runnable这样只能运行或者被中断的状态，也使得客户端更加灵活的控制任务执行。



# API

FutureTask的API全部来自父接口，自己只定义了构造函数，

```java
//任务执行方法，继承自RunnableFuture的run,RunnableFuture又继承在Runnable
public void run() 

//run之后，获取run的结果，可能任务执行被中断，或者执行异常
public V get() throws InterruptedException, ExecutionException 

//带超时的获取run结果，可能抛出超时异常    
public V get(long timeout, TimeUnit unit)  throws InterruptedException, ExecutionException, TimeoutException
    
//取消任务
public boolean cancel(boolean mayInterruptIfRunning)
    
//任务是否被取消   
public boolean isCancelled()
    
//任务是否完成
public boolean isDone()
    
//钩子方法
protected void done() { }
```

# 实现

## 创建

```java
//通过Callable创建FutureTask，并且任务状态设置为NEW
public FutureTask(Callable<V> callable) {
    if (callable == null)
        throw new NullPointerException();
    this.callable = callable;
    this.state = NEW;       // ensure visibility of callable
}
```



```java
//通过Runnable创建FutureTask，并且任务状态设置为NEW
public FutureTask(Runnable runnable, V result) {
    this.callable = Executors.callable(runnable, result);
    this.state = NEW;       // ensure visibility of callable
}
```



## 等待节点WaitNode

等待节点是当有多个线程获取结果的时候，会进行排队，当有一个线程get到结果时候，其他线程将被唤醒，也将拿到结果。该等待节点的实现是Treiber Stack，Treiber 是发明者名字,它是非阻塞的同步栈，详情可参考Wikipedia.  https://en.wikipedia.org/wiki/Treiber_stack

```java
static final class WaitNode {
    volatile Thread thread;
    volatile WaitNode next;
    WaitNode() { thread = Thread.currentThread(); }
}
```

该类的实现是静态final类，意味着这是一个全局的类，和外部实例没有关系，并且不能被继承，



## 实例变量

```java
/** 运行的任务 */
private Callable<V> callable;
/** get返回的结果 */
private Object outcome; // non-volatile, protected by state reads/writes
/** 运行Callable的线程 */
private volatile Thread runner;
/** Treiber stack上的等待线程 */
private volatile WaitNode waiters;
```





## 任务状态

```java
private volatile int state;  //任务状态，每个API都会和状态相关
private static final int NEW          = 0;
private static final int COMPLETING   = 1;
private static final int NORMAL       = 2;
private static final int EXCEPTIONAL  = 3;
private static final int CANCELLED    = 4;
private static final int INTERRUPTING = 5;
private static final int INTERRUPTED  = 6;
```

任务的状态有7种，每种任务状态是递增且不可逆的。下面是状态流转图：

<img src="/images/FutureTaskStatus.png" style="zoom:50%;" />

任务起始状态是NEW，中间过程有COMPLETING和INTERRUPTING，终态有四种，也就是图的叶子节点。这些状态使得任务可以被控制。



## 任务运行run

任务运行是实现run方法，也就是客户端自定义的任务。

run方法首先判断状态，如果任务状态不NEW，则直接退出，防止任务重复执行，然后进入真正任务执行，调用Callable的call方法，

call结束，任务执行完成，将ran置为ture，正常情况调用set，如果运行中发生异常，调用setException，

```java
public void run() {
    //判断状态是不是NEW
    if (state != NEW ||
        !RUNNER.compareAndSet(this, null, Thread.currentThread()))
        return;
    try {
        Callable<V> c = callable;
        if (c != null && state == NEW) {
            V result;
            boolean ran;
            try {
                //真正任务执行
                result = c.call();
                //执行完成设置ran为true
                ran = true;
            } catch (Throwable ex) {
                //任务执行发生异常
                result = null;
                ran = false;
                //修改任务执行状态为异常
                setException(ex);
            }
            if (ran)
                //修改任务执行状态为正常结束
                set(result);
        }
    } finally {
        // runner must be non-null until state is settled to
        // prevent concurrent calls to run()
        runner = null;
        // state must be re-read after nulling runner to prevent
        // leaked interrupts
        int s = state;
        if (s >= INTERRUPTING)
            handlePossibleCancellationInterrupt(s);
    }
}
```



如果发生异常将任务状态设置为EXCEPTIONAL

```java
protected void setException(Throwable t) {
    if (STATE.compareAndSet(this, NEW, COMPLETING)) {
        outcome = t;
        STATE.setRelease(this, EXCEPTIONAL); // final state
        finishCompletion();
    }
}
```

如果正常执行完成，将任务状态设置为NORMAL

```java
protected void set(V v) {
    if (STATE.compareAndSet(this, NEW, COMPLETING)) {
        outcome = v;
        STATE.setRelease(this, NORMAL); // final state
        finishCompletion();
    }
}
```



## 获取任务结果get()

```java
public V get() throws InterruptedException, ExecutionException {
    int s = state;
    if (s <= COMPLETING)
        s = awaitDone(false, 0L);
    return report(s);
}
```

从API可以看出，获取任务结果时候，任务可能被中断，或者发生执行异常。



### awaitDone 自旋等待结果

读这段代码时候，一定要想着会有多个线程来awaitDone，并且每一个线程都在自旋，等待状态变化。每个线程按照排队方式排列在waiters进行等待。

假设有四个线程同时获取结果，每一个运行1s后，才启动另一个线程，那么每个线程第一次进入awaitDone时候将会创建自己的WaitNode，然后第二次进入会发现queued=false，然后将第一次进入的创建WaitNode节点next指向waiters，如Thread1 -> waiters,

第三次进入时候，因为所有的分支条件只满足最后一个，调用LockSupport.park(this)，此时该线程因为一直没有获取结果而进行wait，此时线程状态变成waiting。依次类推，第二个线程进入，第三个线程进入，第四个线程进入，将会形成以下结构：

<img src="/images/FutureTaskStack.png" style="zoom:80%;" />



```java
//timed false说明没有超时时间限制
private int awaitDone(boolean timed, long nanos) throws InterruptedException {
    long startTime = 0L;    // Special value 0L means not yet parked
    WaitNode q = null;
    boolean queued = false;
    //当任务执行时候，一直在自旋等待状态变化，为了不断获取任务执行过程中的状态。
    for (;;) {
        int s = state;
        if (s > COMPLETING) {
            if (q != null)
                //大于COMPLETING的其他状态，直接返回状态,该状态主要改变会在run方法中改变
                q.thread = null;
            return s;
        }
        else if (s == COMPLETING)
            Thread.yield();
        else if (Thread.interrupted()) {
            //线程被中断时候，移除等待节点上的线程，并且告诉客户端发生了中断，
            removeWaiter(q);
            throw new InterruptedException();
        }
        //第一次进入时候，WaitNode为空，创建新的等待节点。
        else if (q == null) {
            if (timed && nanos <= 0L)
                return s;
            q = new WaitNode();
        }
        else if (!queued)
            //如果
            queued = WAITERS.weakCompareAndSet(this, q.next = waiters, q);
        else if (timed) {
            //如果有超时实现限制，则会不断和最终时间进行比较，超过最终时间，状态返回NEW，并且在外层抛出
            //TimeoutException
            final long parkNanos;
            if (startTime == 0L) { // first time
                startTime = System.nanoTime();
                if (startTime == 0L)
                    startTime = 1L;
                parkNanos = nanos;
            } else {
                long elapsed = System.nanoTime() - startTime;
                if (elapsed >= nanos) {
                    removeWaiter(q);
                    return state;
                }
                parkNanos = nanos - elapsed;
            }
            // nanoTime may be slow; recheck before parking
            if (state < COMPLETING)
                //park当前线程
                LockSupport.parkNanos(this, parkNanos);
        }
        else
            //所有排队的线程均会被park住.
            LockSupport.park(this);
    }
}
```

### finishCompletion 完成任务

当有任务完成时候，会将Tribie Stack等待的线程全部unpark，并且释放每个WaitNode的线程.

```java
private void finishCompletion() {
    // assert state > COMPLETING;
    for (WaitNode q; (q = waiters) != null;) {
        if (WAITERS.weakCompareAndSet(this, q, null)) {
            for (;;) {
                Thread t = q.thread;
                if (t != null) {
                    q.thread = null;
                    LockSupport.unpark(t);
                }
                WaitNode next = q.next;
                if (next == null)
                    break;
                q.next = null; // unlink to help gc
                q = next;
            }
            break;
        }
    }

    done();

    callable = null;        // to reduce footprint
}
```





```java
@SuppressWarnings("unchecked")
private V report(int s) throws ExecutionException {
    Object x = outcome;
    if (s == NORMAL)
        return (V)x;
    if (s >= CANCELLED)
        throw new CancellationException();
    throw new ExecutionException((Throwable)x);
}
```



## 带超时的get()

这块和get()其实差不多，只是会进入get的不同for(;;)分支，当超过指定时间没有返回结果时候，将会抛出TimeoutException异常。

```java
public V get(long timeout, TimeUnit unit)
    throws InterruptedException, ExecutionException, TimeoutException {
    if (unit == null)
        throw new NullPointerException();
    int s = state;
    if (s <= COMPLETING &&
        (s = awaitDone(true, unit.toNanos(timeout))) <= COMPLETING)
        throw new TimeoutException();
    return report(s);
}
```



## 取消任务cancel

任务取消成功返回true，取消失败返回false，可以从条件判断中得知，当状态为NEW，且被原子更新为INTERRUPTING或CANCELLED，

才能取消任务。当可以中断时候，任务通过中断实现的，中断之后将任务状态设置为INTERRUPTING，当不可以中断，任务取消其实并没有做什么，只是将任务状态修改为或CANCELLED，当任务状态发生变化时候，一直自旋等待线程会在get方法中获得状态变化，从而执行相关分析，最后执行finishCompletion.

```java
public boolean cancel(boolean mayInterruptIfRunning) {
    if (!(state == NEW && STATE.compareAndSet
          (this, NEW, mayInterruptIfRunning ? INTERRUPTING : CANCELLED)))
        return false;
    try {    // in case call to interrupt throws exception
        if (mayInterruptIfRunning) {
            try {
                Thread t = runner;
                if (t != null)
                    t.interrupt();
            } finally { // final state
                STATE.setRelease(this, INTERRUPTED);
            }
        }
    } finally {
        finishCompletion();
    }
    return true;
}
```



## 是否取消isCancelled

根据状态判断，因为状态是递增的。

```java
public boolean isCancelled() {
    return state >= CANCELLED;
}
```



## 是否完成isDone

同样根据状态判断。

```java
public boolean isDone() {
    return state != NEW;
}
```





# 实战案例
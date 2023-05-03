---
title: ThreadPoolExecutor设计与实现
date: 2020-11-10 14:46:47
tags: java.util.concurrent
categories:
  - JDK源码
  - Java并发框架
---



​      线程池是Java并发包中的重要部分，也是高并发程序必不可少的类库，但是线程池技术本身比较复杂，不同语言对其实现提供的抽象也不一样，所以本文以Java线程池为例，分析它的设计与实现，以及它所带我们的抽象。



# 序言

我对线程池的认识经历了以下三个阶段

1   会使用Executors的API，觉得很cool，很简单。

2   到配置线程池参数，理解线程池参数，池化资源复用，减少上下文切换，参数关系构成了线程池的执行过程。

3  任务，任务提交，任务执行的抽象理解，从ThreadPoolExecutor到ScheduledThreadPoolExecutor到ForkJoinPool，CompletableFuture的理解。



我现在的理解是：Java并发提供了三个核心抽象概念(`任务，任务提交和取消，任务执行`)，具体来说：

1 **任务**  任务的抽象从Runnable，Callable，FutureTask，到ForkJoinTask 子类RecursiveTask，RecursiveAction，以及CompletableFuture中的Completion对ForkJoinTask 的继承，对AsynchronousCompletionTask的实现。

2 **任务提交和取消**  从ExecutorService到ExecutorCompletionService，实现submit，invoke方法，核心子类：AbstractExecutorService作为骨架实现 

3 **任务执行**  从Executor到核心子类ThreadPoolExecutor(核心方法execute)，ForkjoinPool(因为重写了提交机制，所以核心方法submit和execute)，ScheduledThreadPoolExecutor也是种执行机制。纯接口包含了命令模式，模板模式，状态机模式等等。这就意味着你可以自定义提交和执行机制。体现了多种策略和实现分别，非常漂亮。

传统的**new Thread(new Runnable).start()**  将任务，任务提交，任务执行耦合起来，也没有提供任务取消的机制，显得那么得不可用，这篇博文主要以分析ThreadPoolExecutor为主，但是站在更高的抽象层次去看，会理解更深。



# 结构

## 任务结构

![任务结构](/images/JUC-Task-Diagram.png)

每个任务都有其抽象的含义，接下来我们将分析每一个接口的类型。

```java
//代表了任务执行没有结果
public interface Runnable {
	public abstract void run();
}
```



```java
//代表了一个任务执行有结果
public interface Callable<V> {
    V call() throws Exception;
}
```





```java
//任务不仅仅被执行，还可以取消，完成，返回结果，Future对任务的抽象比Runnable更加全面，要知道通过原生Thread API
//去取消一个任务是件复杂的事情
public interface Future<V> {
	//任务可以被中断取消，任务取消能力在Runnable不行的
    boolean cancel(boolean mayInterruptIfRunning);
    //任务是否已经取消
    boolean isCancelled();
    //任务是否完成
    boolean isDone();
    //任务返回结果，获取可能中断，也可能执行异常
    V get() throws InterruptedException, ExecutionException;
	//在指定时间内返回结果
    V get(long timeout, TimeUnit unit)
        throws InterruptedException, ExecutionException, TimeoutException;
}
```



```java
//接口多继承，仅仅是将Runnable和Future的能力结合起来，是一个mixin接口，但是还是强调了run的能力
public interface RunnableFuture<V> extends Runnable, Future<V> {
    void run();
}
```



```java
//真正的任务实现是FutureTask，FutureTask的构造对Callable和Runnable进行包装,使得任务成为FutureTask
// ThreadPoolExecutor里面的实际任务是FutureTask
public class FutureTask<V> implements RunnableFuture<V> {
	public FutureTask(Callable<V> callable) {//忽略}
    public FutureTask(Runnable runnable, V result) {//忽略}
    //FutureTask源码在另外博客中会写，这里着重分析结构
}
```





```java
//ForkJoinTask也是一种Future类型任务，其内部提供了AdaptedRunnable，AdaptedCallable的适配类，
//将任务适配成ForkJoinTask
public abstract class ForkJoinTask<V> implements Future<V>, Serializable {}
```



从上面可以看出，在JUC中，对于任务的抽象其实和任务的执行策略有关系，ThreadPoolExecutor执行的是FutureTask任务，而ScheduledThreadPoolExecutor执行的是ScheduledFutureTask，ForkJoinPool执行的是ForkJoinTask任务，这是多么清晰且统一的设计啊！



## 任务提交和执行结构

<img src="/images/Executor-Class-Diagram.png" alt="任务提交"/>



```java
//顶级接口，定义了任务执行，每一个任务是一个Runnable
public interface Executor {
    void execute(Runnable command);
}
```



但是仅仅有执行还不行，还要管理任务的取消和生命周期，所以提供了ExecutorService接口，如果说Executor定义了任务执行，

那么ExecutorService提供提交定义了任务的提交和取消，提供了更加完整的任务生命周期的概念，注意到在这层抽象上，我们其实并不知道具体任务是怎么执行的(并行？串行？定期)，怎么被提交的，以及怎么返回结果的，真正的实现是具体的实现类。

```java
//Executor提供执行机制，ExecutorService提供提交，取消，完成，等待完成，批量执行任务机制，其中最核心的抽象的提交机制。
public interface ExecutorService extends Executor {
    //结束
	void shutdown();
    //里面结束，返回没有执行完的任务
    List<Runnable> shutdownNow();
    boolean isShutdown();
    boolean isTerminated();
    boolean awaitTermination(long timeout, TimeUnit unit) throws InterruptedException;
    //提交一个Callable，返回一个加强版的任务，可以获得结果，可以取消，可以判断时候完成
	<T> Future<T> submit(Callable<T> task);
    <T> Future<T> submit(Runnable task, T result);
    Future<?> submit(Runnable task);
    //提交一批任务，返回所有的完成结果
    <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks)
        throws InterruptedException;
    <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks,
                                  long timeout, TimeUnit unit)
        throws InterruptedException;
    //返回任意一个结果
    <T> T invokeAny(Collection<? extends Callable<T>> tasks)
        throws InterruptedException, ExecutionException;
    <T> T invokeAny(Collection<? extends Callable<T>> tasks,
                    long timeout, TimeUnit unit)
        throws InterruptedException, ExecutionException, TimeoutException;
    //继承了Executor的execute方法
     void execute(Runnable command);
}
```



可以看出，在抽象层，通过一系列接口来完成“任务，任务执行，任务提交和取消”等机制，而接下来章节将分析一种提交和执行机制，线程池，也就是ThreadPoolExecutor.



# 设计与实现

## ThrealPoolExecutor整体结构

<img src="/images/ThreadPoolExecutor.png" style="zoom:70%;" />





## AbstractExecutorService实现

AbstractExecutorService仅仅为任务提交提供了骨架的实现，并没有为任务执行和取消提供实现，这也是面向接口设计的一个常用技巧，该类并没有实现Executor的execute方法，因为执行机制属于子类，我们其实可以提供默认实现。但是这样抽象类存在的价值将不是很大。

我们来看一下他的提交机制有哪些？

```java
//将任务包装成RunnableFuture，实际子类是FutureTask，然后子类(其实就是ThreadPoolExecutor)实现execute执行任务，最后返回执行后的任务
public Future<?> submit(Runnable task) {
    if (task == null) throw new NullPointerException();
    RunnableFuture<Void> ftask = newTaskFor(task, null);
    execute(ftask);
    return ftask;
}
```



```java
//提交一个FutureTask，子类执行任务
public <T> Future<T> submit(Runnable task, T result) {
    if (task == null) throw new NullPointerException();
    RunnableFuture<T> ftask = newTaskFor(task, result);
    execute(ftask);
    return ftask;
}
```

```java
public <T> Future<T> submit(Callable<T> task) {
    if (task == null) throw new NullPointerException();
    RunnableFuture<T> ftask = newTaskFor(task);
    execute(ftask);
    return ftask;
}
```



```java
//提交一组任务，并且返回所有的任务返回值
public <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks)
    throws InterruptedException {
    if (tasks == null)
        throw new NullPointerException();
    //存放任务返回值的列表
    ArrayList<Future<T>> futures = new ArrayList<Future<T>>(tasks.size());
    boolean done = false;
    try {
        for (Callable<T> t : tasks) {
            RunnableFuture<T> f = newTaskFor(t);
            futures.add(f);
            execute(f);
        }
        for (int i = 0, size = futures.size(); i < size; i++) {
            Future<T> f = futures.get(i);
            if (!f.isDone()) {
                try {
                    f.get();
                } catch (CancellationException ignore) {
                } catch (ExecutionException ignore) {
                }
            }
        }
        //任务全部执行完成成功，返回futures
        done = true;
        return futures;
    } finally {
        //如果没有完成，那么取消所有任务
        if (!done)
            for (int i = 0, size = futures.size(); i < size; i++)
                futures.get(i).cancel(true);
    }
}
```





## FutureTask实现

### 任务执行 

该方法实现RunnableFuture，而RunnableFuture接口继承Runnable的run方法，所有本质是任务执行时候的方法。

```java
public void run() {}
```

### 获取任务结果

```java
public V get() throws InterruptedException, ExecutionException {}
```

### 获取有限时间任务结果

```java
public V get(long timeout, TimeUnit unit)
    throws InterruptedException, ExecutionException, TimeoutException {}
```

### 任务取消

```java
public boolean cancel(boolean mayInterruptIfRunning) {}
```





## ThreadPoolExecutor API

ThreadPoolExecutor 公共API较多，但是每一个都很实用。

我们主要分析和Executor和ExecutorService相关的API

```java
public void execute(Runnable command) {}
```



核心构造函数：

```java
public ThreadPoolExecutor(int corePoolSize,
                          int maximumPoolSize,
                          long keepAliveTime,
                          TimeUnit unit,
                          BlockingQueue<Runnable> workQueue,
                          ThreadFactory threadFactory,
                          RejectedExecutionHandler handler) {
```



## ThreadPoolExecutor实现

ThreadPoolExecutor实现了线程池这种执行任务的机制，所以最核心的方法就是execute，如提交相关的方法，在其父类AbstractExecutorService已经实现了，所以该类其实就是实现了任务执行机制execute.

execute实现提供的抽象概念有，**Worker**和**WorkQueue** . Worker主要处理任务，每一个Worker是一个运行的线程，在runWoker方法中一直轮询WorkQueue的任务并执行，WorkQueue主要用于存储任务。

### 公共API-execute

```java
public void execute(Runnable command) {
    if (command == null)
        throw new NullPointerException();
    int c = ctl.get();
    //没有超过核心线程数，新加worker处理，此时如果添加Worker成功，直接返回，如果失败，？？？
    if (workerCountOf(c) < corePoolSize) {
        if (addWorker(command, true))
            return;
        c = ctl.get();
    }
    //超过核心线程数，任务入队
    if (isRunning(c) && workQueue.offer(command)) {
        int recheck = ctl.get();
        if (! isRunning(recheck) && remove(command))
            reject(command);
        else if (workerCountOf(recheck) == 0)
            addWorker(null, false);
    }
    //任务队列已满，如果添加不到workQueue里面，则拒绝任务，如果能添加，则不拒绝
    else if (!addWorker(command, false))
        reject(command);
}
```



### 私有方法-addWorker

添加worker，并且启动worker，开始执行任务。

```java
private boolean addWorker(Runnable firstTask, boolean core) {
    retry:
    for (;;) {
        int c = ctl.get();
        int rs = runStateOf(c);

        // Check if queue empty only if necessary.
        if (rs >= SHUTDOWN &&
            ! (rs == SHUTDOWN &&
               firstTask == null &&
               ! workQueue.isEmpty()))
            return false;

        for (;;) {
            int wc = workerCountOf(c);
            if (wc >= CAPACITY ||
                wc >= (core ? corePoolSize : maximumPoolSize))
                return false;
            if (compareAndIncrementWorkerCount(c))
                break retry;
            c = ctl.get();  // Re-read ctl
            if (runStateOf(c) != rs)
                continue retry;
            // else CAS failed due to workerCount change; retry inner loop
        }
    }

    boolean workerStarted = false;
    boolean workerAdded = false;
    Worker w = null;
    try {
        w = new Worker(firstTask);
        final Thread t = w.thread;
        if (t != null) {
            final ReentrantLock mainLock = this.mainLock;
            mainLock.lock();
            try {
                // Recheck while holding lock.
                // Back out on ThreadFactory failure or if
                // shut down before lock acquired.
                int rs = runStateOf(ctl.get());

                if (rs < SHUTDOWN ||
                    (rs == SHUTDOWN && firstTask == null)) {
                    if (t.isAlive()) // precheck that t is startable
                        throw new IllegalThreadStateException();
                    //添加worker
                    workers.add(w);
                    int s = workers.size();
                    if (s > largestPoolSize)
                        largestPoolSize = s;
                    workerAdded = true;
                }
            } finally {
                mainLock.unlock();
            }
            if (workerAdded) {
                //启动worker
                t.start();
                workerStarted = true;
            }
        }
    } finally {
        if (! workerStarted)
            addWorkerFailed(w);
    }
    return workerStarted;
}
```



### 私有方法-addWorkerFailed

```java
private void addWorkerFailed(Worker w) {
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        if (w != null)
            workers.remove(w);
        decrementWorkerCount();
        tryTerminate();
    } finally {
        mainLock.unlock();
    }
}
```





### 私有非静态成员类-Worker

Worker即是锁(extends AbstractQueuedSynchronizer)，也是一个工作者线程(implements Runnable)，

```java
//这是一个互斥锁，且不支持重入！一个只能锁定一个任务，一个任务也只能被一个Worker锁住！
private final class Worker extends AbstractQueuedSynchronizer implements Runnable {
    /** Thread this worker is running in.  Null if factory fails. */
    final Thread thread;
    /** Initial task to run.  Possibly null. 第一个任务，后面的任务从workQueue中拿 */
    Runnable firstTask;
    /** Per-thread task counter */
    volatile long completedTasks;

    Worker(Runnable firstTask) {
        setState(-1); // inhibit interrupts until runWorker
        this.firstTask = firstTask;
        this.thread = getThreadFactory().newThread(this);
    }

    /** Delegates main run loop to outer runWorker  */
    public void run() {
        //runWokker是每个worker最核心处理方法，在该方法中，进行任务获取，任务执行
        runWorker(this);
    }
    // The value 0 represents the unlocked state. The value 1 represents the locked state.
    protected boolean isHeldExclusively() {
        return getState() != 0;
    }
    protected boolean tryAcquire(int unused) {
        if (compareAndSetState(0, 1)) {
            setExclusiveOwnerThread(Thread.currentThread());
            return true;
        }
        return false;
    }

    protected boolean tryRelease(int unused) {
        setExclusiveOwnerThread(null);
        setState(0);
        return true;
    }

    public void lock()        { acquire(1); }
    public boolean tryLock()  { return tryAcquire(1); }
    public void unlock()      { release(1); }
    public boolean isLocked() { return isHeldExclusively(); }

    void interruptIfStarted() {
        Thread t;
        if (getState() >= 0 && (t = thread) != null && !t.isInterrupted()) {
            try {
                t.interrupt();
            } catch (SecurityException ignore) {
            }
        }
    }
}
```



### 私有方法runWorker

worker处理task的核心方法，从队列中不停地拿任务。

```java
final void runWorker(Worker w) {
    Thread wt = Thread.currentThread();
    Runnable task = w.firstTask;
    w.firstTask = null;
    w.unlock(); // allow interrupts
    boolean completedAbruptly = true;
    try {
        //如果是prestartAllCoreThreads，将不会进入while循环，只是start一个线程，但是不处理如何任务
        //task != null(少于核心线程数的任务)     task = getTask() 在阻塞队列中的任务
        while (task != null || (task = getTask()) != null) {
            w.lock();
            // If pool is stopping, ensure thread is interrupted;
            // if not, ensure thread is not interrupted.  This
            // requires a recheck in second case to deal with
            // shutdownNow race while clearing interrupt
            if ((runStateAtLeast(ctl.get(), STOP) ||
                 (Thread.interrupted() &&
                  runStateAtLeast(ctl.get(), STOP))) &&
                !wt.isInterrupted())
                wt.interrupt();
            try {
                //扩展钩子方法，任务处理前的方法
                beforeExecute(wt, task);
                Throwable thrown = null;
                try {
                    //这是接口方法，客户端自定义的任务在这里执行，其实从实现来看执行的FutureTask的run方法
                    task.run();
                    //以下异常是任务抛出的异常,如果抛出异常，则退出Main Loop，然后设置completedAbruptly=false
                    //此时会进入processWorkerExit方法
                } catch (RuntimeException x) {
                    thrown = x; throw x;
                } catch (Error x) {
                    thrown = x; throw x;
                } catch (Throwable x) {
                    thrown = x; throw new Error(x);
                } finally {
                    //扩展钩子方法：任务执行后的处理
                    afterExecute(task, thrown);
                }
            } finally {
                task = null;
                w.completedTasks++;
                w.unlock();
            }
        }
        completedAbruptly = false;
    } finally {
        processWorkerExit(w, completedAbruptly);
    }
}
```



### 私有方法-processWorkerExit

该方法用户处理Worker因为异常情况退出，比如任务抛出异常，或者Worker被中断了

```java
private void processWorkerExit(Worker w, boolean completedAbruptly) {
    if (completedAbruptly) // If abrupt, then workerCount wasn't adjusted
        decrementWorkerCount();

    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        completedTaskCount += w.completedTasks;
        //删除Worker
        workers.remove(w);
    } finally {
        mainLock.unlock();
    }

    tryTerminate();

    int c = ctl.get();
    if (runStateLessThan(c, STOP)) {
        if (!completedAbruptly) {
            int min = allowCoreThreadTimeOut ? 0 : corePoolSize;
            if (min == 0 && ! workQueue.isEmpty())
                min = 1;
            if (workerCountOf(c) >= min)
                //工作的Worker大于min，则没必要替换，直接返回
                return; // replacement not needed
        }
        //启动新的Worker处理任务
        addWorker(null, false);
    }
}
```



### 私有方法-getTask

```java
private Runnable getTask() {
    boolean timedOut = false; // Did the last poll() time out?
	//不断在阻塞获取任务
    for (;;) {
        int c = ctl.get();
        int rs = runStateOf(c);

        // Check if queue empty only if necessary.
        if (rs >= SHUTDOWN && (rs >= STOP || workQueue.isEmpty())) {
            decrementWorkerCount();
            return null;
        }

        int wc = workerCountOf(c);

        // Are workers subject to culling?
        boolean timed = allowCoreThreadTimeOut || wc > corePoolSize;

        if ((wc > maximumPoolSize || (timed && timedOut))
            && (wc > 1 || workQueue.isEmpty())) {
            if (compareAndDecrementWorkerCount(c))
                return null;
            continue;
        }

        try {
            //如果allowCoreThreadTimeOut是true，在keepAliveTime时间内，没有任务到来，
            Runnable r = timed ?
                workQueue.poll(keepAliveTime, TimeUnit.NANOSECONDS) :
                workQueue.take();
            if (r != null)
                return r;
            timedOut = true;
        } catch (InterruptedException retry) {
            timedOut = false;
        }
    }
}
```







### 私有方法-interruptIdleWorkers

```java
private void interruptIdleWorkers(boolean onlyOne) {
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        for (Worker w : workers) {
            Thread t = w.thread;
            if (!t.isInterrupted() && w.tryLock()) {
                try {
                    t.interrupt();
                } catch (SecurityException ignore) {
                } finally {
                    w.unlock();
                }
            }
            if (onlyOne)
                break;
        }
    } finally {
        mainLock.unlock();
    }
}
```





### 公共API-shutdown

```java
public void shutdown() {
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        //检查关闭权限
        checkShutdownAccess();
        //线程池状态设置为SHUTDOWN
        advanceRunState(SHUTDOWN);
        //中断所有的空闲的Worker，此时真正执行任务的Worker不会被中断，因为获取不到锁
        interruptIdleWorkers();
        onShutdown(); // hook for ScheduledThreadPoolExecutor
    } finally {
        mainLock.unlock();
    }
    tryTerminate();
}
```



### 公共API-shutdownNow

```java
public List<Runnable> shutdownNow() {
    List<Runnable> tasks;
    final ReentrantLock mainLock = this.mainLock;
    mainLock.lock();
    try {
        checkShutdownAccess();
        advanceRunState(STOP);
        interruptWorkers();
        //workQueue中所有的任务会被取出来，然后交由客户端处理
        tasks = drainQueue();
    } finally {
        mainLock.unlock();
    }
    tryTerminate();
    return tasks;
}
```

### 公共API-allowCoreThreadTimeOut

```java
public void allowCoreThreadTimeOut(boolean value) {
    if (value && keepAliveTime <= 0)
        throw new IllegalArgumentException("Core threads must have nonzero keep alive times");
    if (value != allowCoreThreadTimeOut) {
        allowCoreThreadTimeOut = value;
        if (value)
            interruptIdleWorkers();
    }
}
```



### 公共API-prestartAllCoreThreads

```java
public int prestartAllCoreThreads() {
    int n = 0;
    //firstTask是null,core是true，这时候只会启动线程，但是不会执行任何任务
    while (addWorker(null, true))
        ++n;
    return n;
}
```





### 工具方法

```java
private static int runStateOf(int c)     { return c & ~CAPACITY; }
private static int workerCountOf(int c)  { return c & CAPACITY; }
private static int ctlOf(int rs, int wc) { return rs | wc; }
private static boolean runStateLessThan(int c, int s) {
	return c < s;
}
private static boolean runStateAtLeast(int c, int s) {
	return c >= s;
}

private static boolean isRunning(int c) {
	return c < SHUTDOWN;
}

```



### 静态字段

```java
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));
private static final int COUNT_BITS = Integer.SIZE - 3;
private static final int CAPACITY   = (1 << COUNT_BITS) - 1;

// runState is stored in the high-order bits
private static final int RUNNING    = -1 << COUNT_BITS;
private static final int SHUTDOWN   =  0 << COUNT_BITS;
private static final int STOP       =  1 << COUNT_BITS;
private static final int TIDYING    =  2 << COUNT_BITS;
private static final int TERMINATED =  3 << COUNT_BITS;
```







## Executors实现

Executors是对执行者的静态工厂类，提供了常用的执行策略，并且提供了对任务的包装。



# 实战案例

## tomcat线程池解读

org.apache.tomcat.util.threads.ThreadPoolExecutor 



## 扩展ThreadPoolExecutor



## 多元化的拒绝策略



## Apache HttpComponents Worker

```
WorkerPoolExecutor
```



## Spring的抽象









# 结论和启示
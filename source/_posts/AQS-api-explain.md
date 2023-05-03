---
title: AQS(AbstractQueuedSynchronizer) API分析
date: 2020-11-08 01:18:02
tags: java.util.concurrent
categories:
  - JDK源码
  - Java并发框架

---



# AQS概述

AbstractQueuedSynchronizer是Java用于替代 **Synchronized+内置等待通知(wait/notify)+内置条件队列**的抽象队列同步器，该同步器管理锁，条件变量(状态变量)，条件谓词三元关系，从而技术上实现了锁，条件队列，等待通知，阻塞等同步语义。在JUC中广泛使用，其中有ReentrantLock，ReentrantReadWriteLock，Semaphore，CountDownLatch，ThreadPoolExecutor#Worker，而这些基石又组成了部分并发集合，可见其重要性，该同步器比内置的伸缩性和容错性更好，并且功能比内置的更加强大，文章主要分析AQS API设计，以及如何使用该类实现自定义的锁和同步器。



# AQS API一览

AQS API主要分为以下几类，1 public final 方法 ，用于实现类调用以完成获取锁/释放锁的操作，2  protected final方法，用于实现类获取，原子修改状态变量， 3  protected方法，用于实现类覆写，并且协同 protected final从而真正完成等待/通知的同步语义， 4 私有方法，作为内部实现，并非API，故不分析私有方法。

## public final 方法

```java
public final void acquire(int arg) {
    if (!tryAcquire(arg) && acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
            selfInterrupt();
}

线程以独占方式用于获取锁，如果获取到，tryAcquire(arg)将会实现状态修改，否则线程将会入队，被阻塞。
    
    
public final void acquireInterruptibly(int arg) throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    if (!tryAcquire(arg))
        doAcquireInterruptibly(arg);
}

线程以响应中断的方式获取锁。

public final void acquireShared(int arg) {
    if (tryAcquireShared(arg) < 0)
        doAcquireShared(arg);
}

小于0，共享获取失败，则线程入队阻塞。

public final void acquireSharedInterruptibly(int arg) throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    if (tryAcquireShared(arg) < 0)
        doAcquireSharedInterruptibly(arg);
}

以可响应中断的方式共享获取。

public final boolean release(int arg) {
    if (tryRelease(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h);
        return true;
    }
    return false;
}

以独占方式释放，释放成功将unparkSuccessor.

public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}

以共享方式释放。

public final Collection<Thread> getWaitingThreads(ConditionObject condition)
public final int getWaitQueueLength(ConditionObject condition) 
public final boolean hasContended() 
public final boolean tryAcquireNanos(int arg, long nanosTimeout)
public final boolean tryAcquireSharedNanos(int arg, long nanosTimeout)
```



基本获取/释放方法包含了以**tryXXX**开头的方法，这些方法都需要实现类自己来定义，通过对tryXXX方法覆写，从而实现自定义的获取释放操作。



## protect方法

tryAcquire, tryRelease,isHeldExclusively是实现**独占语义**需要覆写的方法，而tryAcquireShared，tryReleaseShared是实现**共享语义**需要覆写的方法，其内部实现均为throw new UnsupportedOperationException()；简单而言，就是通过状态变量的修改来决定获取锁成功，获取锁失败被阻塞，释放锁失败，释放锁成功唤醒被阻塞线程的简单语义。本质是Synchronized+wait+notify+条件队列语义的高级实现。

```java
protected boolean tryAcquire(int arg)     true,成功获取，false，失败获取，线程将入队阻塞。
protected boolean tryRelease(int arg)     true，成功释放，唤醒被阻塞的线程，false，释放失败。
protected boolean isHeldExclusively()     true，被当前线程持有，false，非当前线程持有。
protected int tryAcquireShared(int arg)   负值，获取失败，线程入队被阻塞，零值，以独占方式获取，正值，以共享方式获取
protected boolean tryReleaseShared(int arg) true，使得所有在获取时候阻塞的线程恢复执行，false 释放失败
```



当理解了protect的语义后，就需要在protect中调用protect final来真正操作状态变量了。



## protect final  方法

```java
protected final int getState()    获取状态
protected final void setState(int newState)  设置状态  
protected final boolean compareAndSetState(int expect, int update)  原子更新状态 
```





# AQS使用实战

当我们实现一个锁或者同步器时候，最重要的思考是你的状态变量是什么？条件谓词是什么？状态变量和条件谓词之间的转换关系？首先应该清晰理解你需要被AQS管理的状态，其次是这些状态之间转换。可以说，状态变量及其转换带来的同步语义是最重要的设计思考。我们先从官方API实例Mutex 和BooleanLatch说起，然后深入JDK例子CountDownLatch，ReentrantLock，Semaphore，最后总结实现AQS的模板。



##  Mutex锁实现

互斥锁是最经典的锁，同一时刻只能有一个线程获取锁，并且不可重入。我们可以以0为释放，1为获取作为状态，当获取锁时候，将状态从0置为1，新的线程再次获取时候，将被阻塞。当释放锁时候，将状态从1置为0，并且唤醒之前被阻塞的线程。

1 状态是什么？ 是否获取锁

2  状态转换？ 获取锁时候，状态从0修改为1，释放锁时候，状态从1修改为0.

3  实现细节？ 实现Lock接口，内部静态final类实现Sync，用于实现AQS的protected方法 ，公共方法调用AQS的public final方法。

我们来看实现：

```java
public class Mutex implements Lock, java.io.Serializable {

   // 内部助手类，桥接模式
   private static class Sync extends AbstractQueuedSynchronizer {
     // Reports whether in locked state
     protected boolean isHeldExclusively() {
         //状态为1，认为是当前线程独占
       return getState() == 1;
     }

     // Acquires the lock if state is zero
     public boolean tryAcquire(int acquires) {
       assert acquires == 1; // Otherwise unused
       if (compareAndSetState(0, 1)) {
         //获取锁时候将状态从0原子更新到1，并且设置当前获取者是自己，获取成功返回true
         setExclusiveOwnerThread(Thread.currentThread());
         return true;
       }
       return false;
     }

     // Releases the lock by setting state to zero
     protected boolean tryRelease(int releases) {
       assert releases == 1; // Otherwise unused
       //释放锁时候状态不能为0
       if (getState() == 0) throw new IllegalMonitorStateException();
       setExclusiveOwnerThread(null);
       //状态更新为0
       setState(0);
       return true;
     }
       
     // Provides a Condition
     Condition newCondition() { return new ConditionObject(); }

     // Deserializes properly
     private void readObject(ObjectInputStream s)
         throws IOException, ClassNotFoundException {
       s.defaultReadObject();
       setState(0); // reset to unlocked state
     }
   }

   // The sync object does all the hard work. We just forward to it.
   private final Sync sync = new Sync();
   //实现lock接口，并且公共方法调用AQS的public final方法
   public void lock()                { sync.acquire(1); }
   public boolean tryLock()          { return sync.tryAcquire(1); }
   public void unlock()              { sync.release(1); }
   public Condition newCondition()   { return sync.newCondition(); }
   public boolean isLocked()         { return sync.isHeldExclusively(); }
   public boolean hasQueuedThreads() { return sync.hasQueuedThreads(); }
   public void lockInterruptibly() throws InterruptedException {
     sync.acquireInterruptibly(1);
   }
   public boolean tryLock(long timeout, TimeUnit unit)
       throws InterruptedException {
     return sync.tryAcquireNanos(1, unit.toNanos(timeout));
   }
 }
```



## BooleanLatch 同步器实现

布尔Latch，可以来回切换，只允许一个信号被唤醒，但是是共享获取的，所以使用tryAcquireShared，tryReleaseShared.

1  状态是什么？获取成功或者失败

2  状态转换？    成功1，失败-1

3  实现细节？ 



```java
public class BooleanLatch {
   private static class Sync extends AbstractQueuedSynchronizer {
     boolean isSignalled() { return getState() != 0; }
     protected int tryAcquireShared(int ignore) {
       //1  共享获取成功   -1 共享获取失败，线程阻塞
       return isSignalled() ? 1 : -1;
     }
     protected boolean tryReleaseShared(int ignore) {
       //释放锁时候，将状态设置为1，并且唤醒被阻塞的线程
       setState(1);
       return true;
     }
   }

   private final Sync sync = new Sync();
   public boolean isSignalled() { return sync.isSignalled(); }
   public void signal()         { sync.releaseShared(1); }
   public void await() throws InterruptedException {
     sync.acquireSharedInterruptibly(1);
   }
 }
```



## CountDownLatch同步器实现

1  状态是什么？ 当前计数值

2  状态转换？每次减少一个计数值，直到0，才进行唤醒，当计数器大于0的时候，一直等待计数器降为0

3  实现细节？共享获取，

```java
//构造函数初始化内部同步器的计数值
public CountDownLatch(int count) {
    if (count < 0) throw new IllegalArgumentException("count < 0");
    this.sync = new Sync(count);
}

//sync的实现
private static final class Sync extends AbstractQueuedSynchronizer {

    Sync(int count) {
        //初始化状态设置计数值为count
        setState(count);
    }

    int getCount() {
        return getState();
    }

    //共享获取，状态为0的时候，获取成功，不为0的时候，获取失败，被阻塞
    protected int tryAcquireShared(int acquires) {
        return (getState() == 0) ? 1 : -1;
    }
	//每次countDown时候，在for循环中不断减少初始化计数值，当减少到0的时候，释放成功，将会唤醒等待线程，当已经成为0的时候
    //将一直释放失败，所以CountDownLatch只能用一次。
    protected boolean tryReleaseShared(int releases) {
        // Decrement count; signal when transition to zero
        for (;;) {
            int c = getState();
            if (c == 0)
                return false;
            int nextc = c-1;
            if (compareAndSetState(c, nextc))
                //降低到0的那一次，返回true，唤醒await的线程
                return nextc == 0;
        }
    }
}

//公共API实现
public void await() throws InterruptedException {
     sync.acquireSharedInterruptibly(1);
}

public void countDown() {
     sync.releaseShared(1);
}
```

在EffectiveJava3的item17中有句话点评到：构造器应该创建完全初始化的对象，并且建立起所有约束关系。CountDownLatch是可变的，但是它的状态被刻意设计的非常小，比如创建一个实例，只能用一次，一旦定时器的计数达到0，就不能再用了。



## ReentrantLock锁实现

1  状态是什么？获取锁操作次数

2  状态转换是什么？同一个线程多次获取锁，累加锁操作次数，对应的多次释放锁，减少锁操作次数

3  实现细节？实现Lock接口，独占锁

```java
//抽象同步器，设计为静态类，作为公平同步器和非公平同步器的父类
abstract static class Sync extends AbstractQueuedSynchronizer {
    private static final long serialVersionUID = -5179523762034025860L;

    abstract void lock();

    /**
     * Performs non-fair tryLock.  tryAcquire is implemented in
     * subclasses, but both need nonfair try for trylock method.
     */
    final boolean nonfairTryAcquire(int acquires) {
        final Thread current = Thread.currentThread();
        int c = getState();
        if (c == 0) {
            if (compareAndSetState(0, acquires)) {
                setExclusiveOwnerThread(current);
                return true;
            }
        }
        else if (current == getExclusiveOwnerThread()) {
            int nextc = c + acquires;
            if (nextc < 0) // overflow
                throw new Error("Maximum lock count exceeded");
            setState(nextc);
            return true;
        }
        return false;
    }

    protected final boolean tryRelease(int releases) {
        int c = getState() - releases;
        if (Thread.currentThread() != getExclusiveOwnerThread())
            throw new IllegalMonitorStateException();
        boolean free = false;
        if (c == 0) {
            free = true;
            setExclusiveOwnerThread(null);
        }
        setState(c);
        return free;
    }

    protected final boolean isHeldExclusively() {
        // While we must in general read state before owner,
        // we don't need to do so to check if current thread is owner
        return getExclusiveOwnerThread() == Thread.currentThread();
    }

    final ConditionObject newCondition() {
        return new ConditionObject();
    }

    final Thread getOwner() {
        return getState() == 0 ? null : getExclusiveOwnerThread();
    }

    final int getHoldCount() {
        return isHeldExclusively() ? getState() : 0;
    }

    final boolean isLocked() {
        return getState() != 0;
    }
}

//公平同步器，静态final类
static final class FairSync extends Sync {

    final void lock() {acquire(1);}

    protected final boolean tryAcquire(int acquires) {
        final Thread current = Thread.currentThread();
        int c = getState();
        if (c == 0) {
            //第一次获取，判断如果没有后继者，将锁操作次数修改为acquires，并且设置自己是锁的拥有者，
            //setExclusiveOwnerThread是中的AbstractOwnableSynchronizer方法
            if (!hasQueuedPredecessors() && compareAndSetState(0, acquires)) {
                setExclusiveOwnerThread(current);
                return true;
            }
        }
        //第二次获取，如果还是自己，则将锁获取次数累加，并且修改状态为锁的获取次数，这里也是可重入的实现，当超过
        //锁最大可获取次数，则抛出Error，注意Error是非受检异常
        else if (current == getExclusiveOwnerThread()) {
            int nextc = c + acquires;
            if (nextc < 0)
                throw new Error("Maximum lock count exceeded");
            setState(nextc);
            return true;
        }
        return false;
    }
}

//非公平同步器，静态final类
static final class NonfairSync extends Sync {
    private static final long serialVersionUID = 7316153563782823691L;

    /**
         * Performs lock.  Try immediate barge, backing up to normal
         * acquire on failure.
         */
    final void lock() {
        if (compareAndSetState(0, 1))
            setExclusiveOwnerThread(Thread.currentThread());
        else
            acquire(1);
    }

    protected final boolean tryAcquire(int acquires) {
        return nonfairTryAcquire(acquires);
    }
}

//公有API
//构造器
public ReentrantLock() {
    //默认非公平
    sync = new NonfairSync();
}

public ReentrantLock(boolean fair) {
    sync = fair ? new FairSync() : new NonfairSync();
}

public void lock() {sync.lock();}
public void lockInterruptibly() throws InterruptedException {sync.acquireInterruptibly(1);}
public Condition newCondition() { return sync.newCondition();}
public boolean tryLock() {
    //tryLock时候，无论公平锁还是非公平锁，都是非公平获取
    return sync.nonfairTryAcquire(1);
}
public void unlock() {
    //减少一次锁获取次数
    sync.release(1);
}


```



由此我们可以看到，可重入锁的最大次数是int最大值，也就是2147483647 ，同一个线程最大可以递归获取锁21亿次。



## Semaphore同步器实现

1  状态是什么？当前可用许可数量

2  状态切换？ 每当有一个线程获取到许可时候，就将许可减1，当许可减低为0的时候，阻塞线程，直到许可大于0

3 实现细节？可共享获取

```java
abstract static class Sync extends AbstractQueuedSynchronizer {
    private static final long serialVersionUID = 1192457210091910933L;

    Sync(int permits) {
        setState(permits);
    }

    final int getPermits() {
        return getState();
    }

    final int nonfairTryAcquireShared(int acquires) {
        for (;;) {
            //可用许可
            int available = getState();
            //剩余许可
            int remaining = available - acquires;
            //剩余许可小于0或者将可用修改为剩余
            if (remaining < 0 || compareAndSetState(available, remaining))
                return remaining;
        }
    }

    protected final boolean tryReleaseShared(int releases) {
        for (;;) {
            int current = getState();
            int next = current + releases;
            if (next < current) // overflow
                throw new Error("Maximum permit count exceeded");
            if (compareAndSetState(current, next))
                return true;
        }
    }

    final void reducePermits(int reductions) {
        for (;;) {
            int current = getState();
            int next = current - reductions;
            if (next > current) // underflow
                throw new Error("Permit count underflow");
            if (compareAndSetState(current, next))
                return;
        }
    }

    final int drainPermits() {
        for (;;) {
            int current = getState();
            if (current == 0 || compareAndSetState(current, 0))
                return current;
        }
    }
}

//公平同步器
static final class FairSync extends Sync {
    FairSync(int permits) {
        super(permits);
    }

    protected int tryAcquireShared(int acquires) {
        for (;;) {
            //是否有前继者，如果线程有前继者，说明已有线程被阻塞，直接返回获取失败
            if (hasQueuedPredecessors())
                return -1;
            int available = getState();
            int remaining = available - acquires;
            //剩余小于0或者可用修改为剩余，如果大于0，则获取成功，如果等于0，则独占获取，如果小于0，则获取失败
            //所有当剩余许可小于0的时候，也就是信号量使用完的时候，线程获取锁将被阻塞
            if (remaining < 0 || compareAndSetState(available, remaining))
                return remaining;
        }
    }
}

//非公平同步器
static final class NonfairSync extends Sync {
    NonfairSync(int permits) {
        super(permits);
    }

    protected int tryAcquireShared(int acquires) {
        return nonfairTryAcquireShared(acquires);
    }
}

//公共API
//构造函数
public Semaphore(int permits) { sync = new NonfairSync(permits);}

public Semaphore(int permits, boolean fair) {
    sync = fair ? new FairSync(permits) : new NonfairSync(permits);
}

public void acquire() throws InterruptedException {
    sync.acquireSharedInterruptibly(1);
}

 public void acquire(int permits) throws InterruptedException {
     if (permits < 0) throw new IllegalArgumentException();
     sync.acquireSharedInterruptibly(permits);
 }

public void release() {
    sync.releaseShared(1);
}

public void release(int permits) {
    if (permits < 0) throw new IllegalArgumentException();
    sync.releaseShared(permits);
}

```



我们可以看到，Semaphore是初始化N个许可，线程无需等待，然后每一个线程会消耗信号量，当消耗完时，会阻塞后面线程，而CountDownLatch是初始化N个计数器，然后线程等待，当计数器降为0的时候，唤醒初始化等待的线程，这两者有些相反的含义在里面。两种同用共享获取方式，共享释放释放。



# 4  总结

在实现锁或者同步器时候，需要思考以下几点：

1  状态变量以及状态变量的转换

2   是独占的还是共享的

当想明白以上两个问题时候，就可以动手实现你要的同步器的，一般是以内部静态类的方式继承AQS的protected方法，在protected方法中，调用protected final方法，然后在你要公共API中调用你的内部同步器的public final方法既可。如下实现模板：

```java
public MyLock implements Lock,  or MySync {

   //内部同步器，继承AQS的protected方法，里面调用AQS的protected final方法修改状态
   innerStaticSync extends AbstractQueuedSynchronizer{

       //独占获取 tryAcquire，tryRelease，isHeldExclusively
       protected boolean tryAcquire(int arg) {
           getState/setState/compareAndSetState
       }
       protected boolean tryRelease(int arg) {}
       protected boolean isHeldExclusively() {}
       //共享获取 tryAcquireShared，tryReleaseShared
       protected int tryAcquireShared(int arg) {}
       protected boolean tryReleaseShared(int arg) {}
   }
	//构造函数实例化
    public MyLock or MySync {
        innerStaticSync = new MyLock() or new MySync();
    }

    //public api 调用AQS的public final方法
    public acquire(){innerStaticSync.acquire();}
    public release(){innerStaticSync.release();}
}
```



Done！
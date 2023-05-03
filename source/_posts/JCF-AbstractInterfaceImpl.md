---
title: Java集合框架(2)-抽象实现骨架
date: 2020-11-09 02:34:19
tags: 
  - java.util.*
  - java collection framework
categories:
  - JDK源码
  - Java集合框架
---

# 概述

**接口定义类型，抽象类实现骨架**。抽象类不支持的实现方法便是细节。这种技巧在JCF中是标配。一来替客户端提供如何实现一个接口的最直接的参考。二来帮助客户端以此实现功能更强的接口。如Guava的集合也是参考这种模式。



# 抽象实现

抽象类的最重要分析是留下了哪些抽象方法，而留下的抽象方法是真正实现类的差异，而抽象类中的普通方法使用抽象方法来实现，而抽象方法实现由实现类实现，并且抽象类没有任何字段，所以也能从侧面体现留下的抽象方法的价值。可以认为抽象实现是模板模式的一种应用。



## AbstractCollection

```java
//这是AbstractCollection最核心的两个抽象方法，其余方法实现均是调用这两者
public abstract Iterator<E> iterator();
public abstract int size();
```



### isEmpty

```java
//非常简单，size()=0
public boolean isEmpty() {
    return size() == 0;
}
```



### contains

```java
//通过遍历迭代器来查找元素，元素为空，找出Collection中第一个为空的元素，元素不为空，
//找出第一个在集合中的元素，对象需要实现equals方法
public boolean contains(Object o) {
    Iterator<E> it = iterator();
    if (o==null) {
        while (it.hasNext())
            if (it.next()==null)
                return true;
    } else {
        while (it.hasNext())
            if (o.equals(it.next()))  //对象equals方法很重要
                return true;
    }
    return false;
}
```



### add

```java
//抛出异常，因为子类可以实现可变或者不可变集合
public boolean add(E e) {
    throw new UnsupportedOperationException();
}
```

### remove

```java
//通过迭代器删除，equals方法很重要
public boolean remove(Object o) {
    Iterator<E> it = iterator();
    if (o==null) {
        while (it.hasNext()) {
            if (it.next()==null) {
                it.remove();
                return true;
            }
        }
    } else {
        while (it.hasNext()) {
            if (o.equals(it.next())) {
                it.remove();
                return true;
            }
        }
    }
    return false;
}
```



### containsAll

```java
//时间复杂度为O(n^2)
public boolean containsAll(Collection<?> c) {
    for (Object e : c)
        if (!contains(e))
            return false;
    return true;
}
```



### addAll

```java
//modified来判断集合是否改变
public boolean addAll(Collection<? extends E> c) {
    boolean modified = false;
    for (E e : c)
        if (add(e))
            modified = true;
    return modified;
}
```



### removeAll

```java
//通过迭代器删除
public boolean removeAll(Collection<?> c) {
    Objects.requireNonNull(c);
    boolean modified = false;
    Iterator<?> it = iterator();
    while (it.hasNext()) {
        if (c.contains(it.next())) {
            it.remove();
            modified = true;
        }
    }
    return modified;
}
```



### clear

```java
//遍历迭代器，删除元素
public void clear() {
    Iterator<E> it = iterator();
    while (it.hasNext()) {
        it.next();
        it.remove();
    }
}
```



我们可以看到抽象方法在实现普通方法时候是基本每个方法都会调用。



## AbstractList

```java
//AbstractList抽象方法有两个，1是新定义的get 2是继承父类的size，而父类AbstractCollection中的抽象方法只实现了一个iterator()，因为对于List来说，iterator行为是确认的。但是get行为需要子类实现。
public abstract E get(int index);
```



在AbstractList实现中，定义了Itr, ListItr两个迭代器，以及用于实现内部视图的SubList和RandomAccessSubList.



### iterator

```java
public Iterator<E> iterator() {
    return new Itr();
}
```

### Itr

```java
private class Itr implements Iterator<E> {
    /** 游标位置，指向当前元素**/
    int cursor = 0;
    /**调用next后之前的元素，-1说明刚被删除了*/
    int lastRet = -1;
    /**
     *期望修复次数是不是等于实际修改次数，用户判断遍历时候是否被修改，如果不同则会抛出ConcurrentModificationException
     * 因为这些集合不是在线程安全的，所以并发修改会报错。
     */
    int expectedModCount = modCount;

    public boolean hasNext() {
        return cursor != size();
    }
    public E next() {
        checkForComodification();//检查是否被修改
        try {
            int i = cursor; //当前位置的cursor存储起来
            E next = get(i);//抽象方法get获取元素
            lastRet = i;//更新上一个元素位置
            cursor = i + 1;//cursor下移一位
            return next;//返回当前元素
        } catch (IndexOutOfBoundsException e) {
            checkForComodification();
            throw new NoSuchElementException();
        }
    }
	//删除某个元素
    public void remove() {
        if (lastRet < 0)
            throw new IllegalStateException();
        checkForComodification();
        try {
            AbstractList.this.remove(lastRet);//调用删除方法
            if (lastRet < cursor) //
                cursor--;
            lastRet = -1;//lastRet设置为-1
            expectedModCount = modCount;//修改次数等于期望修改次数
        } catch (IndexOutOfBoundsException e) {
            throw new ConcurrentModificationException();
        }
    }

    final void checkForComodification() {
        if (modCount != expectedModCount)
            throw new ConcurrentModificationException();
    }
}
```

### ListItr

ListItr实现了ListIterator接口，ListIterator和Iterator不同之处在于Iterator只支持向后遍历，但是ListIterator同时支持向后和向前遍历。也支持任意位置开始的遍历。

```java
public interface ListIterator<E> extends Iterator<E> {
	boolean hasNext();
    E next();
    boolean hasPrevious();
    E previous();
    int nextIndex();
    int previousIndex();
    void remove();
    void set(E e);
    void add(E e);
}
```



```java
private class ListItr extends Itr implements ListIterator<E> {
    ListItr(int index) {
        cursor = index;
    }

    public boolean hasPrevious() {
        return cursor != 0;
    }

    public E previous() {
        checkForComodification();
        try {
            int i = cursor - 1;//前一个元素索引
            E previous = get(i);//获取前一个元素
            lastRet = cursor = i;//设置lastRet = cursor等于前一个元素索引
            return previous;
        } catch (IndexOutOfBoundsException e) {
            checkForComodification();
            throw new NoSuchElementException();
        }
    }

    public int nextIndex() {
        return cursor;
    }

    public int previousIndex() {
        return cursor-1;
    }

    public void set(E e) {
        if (lastRet < 0)
            throw new IllegalStateException();
        checkForComodification();

        try {
            AbstractList.this.set(lastRet, e);
            expectedModCount = modCount;
        } catch (IndexOutOfBoundsException ex) {
            throw new ConcurrentModificationException();
        }
    }

    public void add(E e) {
        checkForComodification();

        try {
            int i = cursor;
            AbstractList.this.add(i, e);
            lastRet = -1;
            cursor = i + 1;
            expectedModCount = modCount;
        } catch (IndexOutOfBoundsException ex) {
            throw new ConcurrentModificationException();
        }
    }
}
```



### SubList



### RandomAccessSubList







## AbstractSequentialList

AbstractSequentialList新加创建List迭代器的抽象方法listIterator。

```java
public abstract ListIterator<E> listIterator(int index);
```



## AbstractSet

AbstractSet没有新加任何抽象方法，由于继承了AbstractCollection，所以它的实现是基于iterator和size的。



## AbstractMap

AbstractMap中的抽象方法只有entrySet，可以推断其他方法均是基于该方法实现的。因为键值对的唯一性，所以使用Set存储每一个Entry，虽然Entry好像是数据类，但是本质是有行为的类。每一个Entry代表了一个键值对，我们只能修改value，获取kv，但是不能修改key，这是Entry接口带来的契约，也是设计Entry的点，如果key可以被更新，那么这个map行为将变得不可预期。

```java
public abstract Set<Entry<K,V>> entrySet();
```



```java
//我们注意到Entry对KV的抽象，
interface Entry<K, V> {
    K getKey();
    V getValue();
    V setValue(V value);
    boolean equals(Object o);
    int hashCode();
}		
```



AbstractMap中提供了两个Map.Entry的实现，一个可变的SimpleEntry，一个不可变的SimpleImmutableEntry.SimpleEntry的实现非常简单，没有任何难以理解的地方，我们来看下：

### SimpleEntry

```java
public static class SimpleEntry<K,V> implements Entry<K,V>, java.io.Serializable{
    
    @SuppressWarnings("serial") // Conditionally serializable
    private final K key;
    @SuppressWarnings("serial") // Conditionally serializable
    private V value;

    public SimpleEntry(K key, V value) {
        this.key   = key;
        this.value = value;
    }
    public SimpleEntry(Entry<? extends K, ? extends V> entry) {
        this.key   = entry.getKey();
        this.value = entry.getValue();
    }

    public K getKey() { return key;}

    public V getValue() {return value; }

    public V setValue(V value) {
        V oldValue = this.value;
        this.value = value;
        return oldValue;
    }

    public boolean equals(Object o) {
        if (!(o instanceof Map.Entry))
            return false;
        Map.Entry<?,?> e = (Map.Entry<?,?>)o;
        return eq(key, e.getKey()) && eq(value, e.getValue());
    }

    public int hashCode() {
        return (key   == null ? 0 :   key.hashCode()) ^
               (value == null ? 0 : value.hashCode());
    }

    public String toString() {
        return key + "=" + value;
    }
}
```



### SimpleImmutableEntry

和SimpleEntry不同的地方在于setValue方法抛出UnsupportedOperationException异常。

```java
public V setValue(V value) {
    throw new UnsupportedOperationException();
}
```



### 查询方法实现

```java
//查询操作
public int size() {
   return entrySet().size();//调用抽象方法实现，set().size()
}
public boolean isEmpty() {
   return size() == 0;
}

//时间复杂度O(N)
public boolean containsKey(Object key) {
    //取出Set的迭代器进行key的查找，
    Iterator<Map.Entry<K,V>> i = entrySet().iterator();
    if (key==null) {
        while (i.hasNext()) {
            Entry<K,V> e = i.next();
            if (e.getKey()==null)
                return true;
        }
    } else {
        while (i.hasNext()) {
            Entry<K,V> e = i.next();
            if (key.equals(e.getKey()))
                return true;
        }
    }
    return false;
}


//时间复杂度O(N)
public boolean containsValue(Object value) {
    Iterator<Entry<K,V>> i = entrySet().iterator();
    if (value==null) {
        while (i.hasNext()) {
            Entry<K,V> e = i.next();
            if (e.getValue()==null)
                return true;
        }
    } else {
        while (i.hasNext()) {
            Entry<K,V> e = i.next();
            if (value.equals(e.getValue()))
                return true;
        }
    }
    return false;
}


//这里的get方法实现复杂度是O(N),因为需要遍历整个Entry Set迭代器，这只是
//一种实现方法，如果客户端有更加高效的实现方式，则可以覆写该方法，如HashMap
//的高品质实现，同时因为Map只是定义了接口，并不是实现，Abstract只是定义了
//一种简单的实现，帮助客户端减少实现难度。
public V get(Object key) {
    Iterator<Entry<K,V>> i = entrySet().iterator();
    if (key==null) {
        while (i.hasNext()) {
            Entry<K,V> e = i.next();
            if (e.getKey()==null)
                return e.getValue();
        }
    } else {
        while (i.hasNext()) {
            Entry<K,V> e = i.next();
            if (key.equals(e.getKey()))
                return e.getValue();
        }
    }
    return null;
}

```





### 修改操作方法

```java
//put方法在这里没有实现，也没有办法实现，正如add方法在AbstractCollection/List/Set中无法实现一样
//因为你不知道放入的数据结构，真正的数据结构定义是在实现类中，如HashMap，TreeMap这里面，
//正是因为抽象类的实现没有引入成员变量，所以放入时候才不会指定特定的存储细节，这也是
//集合框架获得灵活性的重要机制，如果在抽象类中引入了成员变量作为存储结构，那么子类的实现将会
//被束缚在抽象类，此时抽象类将不再抽象，而是一种实现了。
public V put(K key, V value) {
    throw new UnsupportedOperationException();
}

public void putAll(Map<? extends K, ? extends V> m) {
        for (Map.Entry<? extends K, ? extends V> e : m.entrySet())
            put(e.getKey(), e.getValue());
}

public void clear() {
    //entrySet是抽象方法
    entrySet().clear();
}

//删除一个key，其实遍历entrySet，找到key对应的Entry，然后调用迭代器remove方法
//删除该元素
public V remove(Object key) {
        Iterator<Entry<K,V>> i = entrySet().iterator();
        Entry<K,V> correctEntry = null;
        if (key==null) {
            while (correctEntry==null && i.hasNext()) {
                Entry<K,V> e = i.next();
                if (e.getKey()==null)
                    correctEntry = e;
            }
        } else {
            while (correctEntry==null && i.hasNext()) {
                Entry<K,V> e = i.next();
                if (key.equals(e.getKey()))
                    correctEntry = e;
            }
        }

        V oldValue = null;
        if (correctEntry !=null) {
            oldValue = correctEntry.getValue();
            i.remove();
        }
        return oldValue;
    }

```



### 视图方法

```java
transient Set<K>        keySet;
transient Collection<V> values;
```



```java
//key的视图是set，因为key不能重复，每个Map只有一个视图，每个视图通过entrySet引用了
//真正Map的元素，可以看出视图实现了AbstractSet.第一次调用时候，keySet视图为空，创建视图。
//第二次调用时候，使用第一次的视图。
public Set<K> keySet() {
    Set<K> ks = keySet;
    if (ks == null) {
        ks = new AbstractSet<K>() {
            public Iterator<K> iterator() {
                return new Iterator<K>() {
                    private Iterator<Entry<K,V>> i = entrySet().iterator();

                    public boolean hasNext() {
                        return i.hasNext();
                    }
					//next是key
                    public K next() {
                        return i.next().getKey();
                    }

                    public void remove() {
                        i.remove();
                    }
                };
            }

            public int size() {
                return AbstractMap.this.size();
            }

            public boolean isEmpty() {
                return AbstractMap.this.isEmpty();
            }

            public void clear() {
                AbstractMap.this.clear();
            }

            public boolean contains(Object k) {
                return AbstractMap.this.containsKey(k);
            }
        };
        keySet = ks;
    }
    return ks;
}
```





```java
//因为value可以有重复的，所以使用Collection存储
public Collection<V> values() {
    Collection<V> vals = values;
    if (vals == null) {
        vals = new AbstractCollection<V>() {
            public Iterator<V> iterator() {
                return new Iterator<V>() {
                    private Iterator<Entry<K,V>> i = entrySet().iterator();

                    public boolean hasNext() {
                        return i.hasNext();
                    }

                    public V next() {
                        return i.next().getValue();
                    }

                    public void remove() {
                        i.remove();
                    }
                };
            }

            public int size() {
                return AbstractMap.this.size();
            }

            public boolean isEmpty() {
                return AbstractMap.this.isEmpty();
            }

            public void clear() {
                AbstractMap.this.clear();
            }

            public boolean contains(Object v) {
                return AbstractMap.this.containsValue(v);
            }
        };
        values = vals;
    }
    return vals;
}
```
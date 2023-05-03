---
title: 动态代理Proxy的设计与实现
date: 2020-11-21 21:59:46
tags: 
  - java.lang.reflect
  - Java-Core
categories:
  - JDK源码
  - Java核心
---



# 序言

Java动态代理实现是基于反射和动态生成Class文件的技术，Proxy，InvocationHandler，Method是三个核心类，Proxy是代理类的入口，用来获取代理类，创建代理实例，获取InvocationHandler，判断某个类是否是代理类，InvocationHandler是方法调用的拦截，invoke方法是接口唯一方法，Method是反射的方法，用来完成方法调用。



# 案例看行为

我们先通过一个Person案例来看动态代理生成的代理类的模样。

```java
//公共接口
interface Person {
    String getName();
    void setName(String name);
}
//公共接口实现
class PersonImpl implements Person {
    private String name;
    @Override
    public String getName() { return name; }
    @Override
    public void setName(String name) { this.name = name; }
}
//调用处理器
class MyInvocationHandler implements InvocationHandler {
    private Person person;
    public MyInvocationHandler(Person person) {
        this.person = person;
    }
    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        System.out.println("before invoke");
        Object invoke = method.invoke(person, args);
        System.out.println("after invoke");
        return invoke;
    }
}
public class PersonProxy {
    public static void main(String[] args) {
        //生成动态代理类文件
        System.getProperties().put("jdk.proxy.ProxyGenerator.saveGeneratedFiles", "true");
        //通过Proxy.newProxyInstance创建动态代理类，并且转型成Person。Person本质是$Proxy0代理类。
        Person person = (Person) Proxy.newProxyInstance(
                Person.class.getClassLoader(), //类加载器
                new Class[]{Person.class},  //接口
                new MyInvocationHandler(new PersonImpl())  //调用处理器
        );
        person.setName("lili");//动态代理类调用setName
        System.out.println(person.getName());//动态代理类调用getName
    }
}
```



我们可以看下生成的$Proxy0类，该类是真正的代理类。分析可知：该类是final说明不可被子类化，并且继承Proxy的构造函数，这也就是Proxy构造函数为什么是protect的原因，同时实现了Person接口，说明代理类可以转型为Person，从而可以调用Person方法产生代理行为，在方法层面，所有的方法都是final方法。在$Proxy0 m0，m1，m2始终为hashCode，equals，toString方法，而m3，m4 ...... 为目标接口的方法，我们可以看到当$Proxy0调用setName时候，实质调用了h.invoke(this, m4, new Object[]{var1})方法，也就是我们自定义的MyInvocationHandler#invoke方法，从而产生代理行为。

```java
public final class $Proxy0 extends Proxy implements Person {
    private static Method m0;//hashCode
    private static Method m1;//equals
    private static Method m2;//toString
    private static Method m3;//getName
    private static Method m4;//setName
    //继承Proxy构造方法
    public $Proxy0(InvocationHandler param1) {
        super(var1);
    }

    public final int hashCode() {
         return (Integer)super.h.invoke(this, m0, (Object[])null);
    }

    public final boolean equals(Object var1) {
        return (Boolean)super.h.invoke(this, m1, new Object[]{var1});
    }

    public final String toString() {
        return (String)super.h.invoke(this, m2, (Object[])null);
    }

    public final String getName() {
        return (String)super.h.invoke(this, m3, (Object[])null);
    }

    public final void setName(String var1) {
         super.h.invoke(this, m4, new Object[]{var1});
    }
	//获取到method对象
    static {      
        m0 = Class.forName("java.lang.Object").getMethod("hashCode");
        m1 = Class.forName("java.lang.Object").getMethod("equals", Class.forName("java.lang.Object"));
        m2 = Class.forName("java.lang.Object").getMethod("toString");
        m3 = Class.forName("org.lili.jdk.lang.reflect.Person").getMethod("getName");
        m4 = Class.forName("org.lili.jdk.lang.reflect.Person").getMethod("setName", Class.forName("java.lang.String"));
    }
}
```



# 结构

通过案例，我们可以勾画出动态代理的结构

![](/images/Proxy.png)

$Proxy0作为Proxy，Person作为Subject，而PersonImpl作为RealSubject是和设计模式代理模式一模一样。

![](/images/GOF-Proxy.png)



# 实现


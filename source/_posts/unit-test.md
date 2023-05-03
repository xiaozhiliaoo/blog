---
title: 持续集成之实践单元测试
date: 2020-12-02 01:13:05
tags:
  - 单元测试
categories:
  - 持续集成
  - 单元测试
---



# 绪论

**单元测试**是保证质量，降低风险的一种重要工具。但是独立的单元测试本身意义不大，但是整合在CI使之成为**自动化测试**中就会体现其价值，这是一个价值流的传递过程，每一个过程传递软件质量和风险的信息。高质量的代码是**CLEAN**的并且**易测试**的，C(Cohesive内聚)，L(Loosely Couped松散耦合) E(Encapsulated 封装) Assertive(自主) Nonredundant(无冗余)，但是单元测试又是怎么影响这些特性的呢？

**Design**：如果我的代码很难测试，那么对客户端来说设计不佳。

**Cohesive**：如果需要为一个类编写很多测试，就会意识到内聚性不足。

**Loosely Couped**：如果我的测试有很多无关的依赖，那么一定是耦合过多了。 

**Encapsulated**：如果我的测试依赖于实现细节，那么肯定是封装出现了问题。

**Assertive**：如果测试结果在被测对象以外对象中体现，我的对象可能不够自主。

**Nonredundant**：如果我一遍一遍编写同样的测试，那肯定出现了冗余。



一个常规的CI流程如下：

<img src="/images/CI.png" style="zoom:80%;" />

从编译源码-》持续集成数据库-》持续测试-》持续审查-》持续部署-》持续反馈，我们在编译源码和持续部署做的很好，但是在改进质量并降低风险的**持续测试**和**持续审查**做的不好，导致软件质量差，代码烂，重复率高。本文主要对持续测试中的单元测试作为实战基础来讲解一个例子，因为这是一个起点，虽然单独通过**持续审查**也能提高质量，但是由于业务压力和人员变更使得代码变乱，光靠审查无法为迭代的业务提供持续的重构保证，也无法自动化基础设施。



# 实战案例

## 基础框架

单元测试框架[junit5](https://junit.org/junit5/)，mock框架[mockito](https://site.mockito.org/)，断言框架[assertj](https://joel-costigliola.github.io/assertj/ ) 



## 案例一:使用Mock取代依赖

以下这段代码即调用了Redis，也调用了第三方接口，还调用了数据库，是一个比较综合的案例，我们来一起看看如何将他变成方便测试的代码，并且保证如何通过单元测试达到覆盖率。

```java
public class TaskCenterWithdrawServiceImpl implements TaskCenterWithdrawService {
    @Autowired
    private HttpEncryptDecryptEngine remote;//调用第三方
    @Autowired
    private WithdrawService withdrawService;//关联DB
   
    public void startWithdraw(String coinSymbol, String walletSymbol, String appId,
                              TransactionWithdrawCrypto twc) {
        
        TransactionWithdrawCrypto withdrawCrypto = withdrawService.selectByIdAndLock(twc.getId());//查询数据库
        String payload = generateWithdrawRequest(coinSymbol, walletSymbol, withdrawCrypto);//构造请求参数，里面查询静态方法
        String result = remote.startWithdraw(appId, payload);//调用第三方接口返回结果
        WalletResponseCode responseCode = WalletResponseCode.ofCode(result);
        switch (responseCode) {
            case SUCCESS:
                break;
            case WITHDRAW_ADDR_ERROR:
            case WITHDRAW_CANNOT_TO_SELF: {
                try {
                    withdrawService.cancelWithdraw();
                } catch (Exception e) {
                    log.error("startWithdrawRequest cancel withdrawCrypto id : {} error ",
                              withdrawCrypto.getId(), e);
                }
                break;
            }   
            default:                
                cancelWithdrawIfAdminConfiged(withdrawCrypto.getId(), responseCode);
                break;
          
    }
```



```java
private String generateWithdrawRequest(String coinSymbol, String walletSymbol,
                                       TransactionWithdrawCrypto c) {
   
    //......里面查询了redis
    ConfigCoinSymbol c = CoinSymbolUtils.getSaaSInfo(coinSymbol);
    //......
    return ....;
}
```



我们看到这个代码，需要思考测试什么才能证明代码没有错呢？既当什么情况下，你期望发生什么。来看看我们得期望：

1   当第三方接口返回成功时候，该方法结束。

2   当第三方接口返回WITHDRAW_ADDR_ERROR或者WITHDRAW_CANNOT_TO_SELF，我们需要调用cancelWithdraw，

3   当第三方接口返回其他情况时候，调用cancelWithdrawIfAdminConfiged方法。

4   当传入不同币种的时候，generateWithdrawRequest产生不同的请求。

我们仅仅需要验证这些就够了，因为TaskCenterWithdrawServiceImpl得协作者的产生的行为仅仅如此，至于协作者行为的可靠性，需要协作者自身去验证，而不是在该测试中验证。

### 第一步 依赖注入解耦

spring字段注入导致单元测试困难，因为你无法实例化类中的对象，所以在TaskCenterWithdrawServiceImpl中将字段注入改成构造器注入或者属性注入。

```java
public class TaskCenterWithdrawServiceImpl {

    private HttpEncryptDecryptEngine httpEncryptDecryptEngine;

    private WithdrawService withdrawService;

    @Autowired
    public void setHttpEncryptDecryptEngine(HttpEncryptDecryptEngine httpEncryptDecryptEngine) {
        this.httpEncryptDecryptEngine = httpEncryptDecryptEngine;
    }

    @Autowired
    public void setWithdrawService(WithdrawService withdrawService) {
        this.withdrawService = withdrawService;
    }

```


### 第二步 静态方法抽离接口

不是所有静态方法都需要抽离成接口，由于项目中CoinSymbolUtils.getSaaSInfo调用了数据库和redis，所以此时你无法真实调用数据库和redis，因为在脱离spring环境你无法创建这两个对象，所以抽离成接口可以mock改接口。如果是普通的工具类，让他执行即可。

```java
public interface CoinSymbolOperator {
    ConfigCoinSymbol getSaaSInfoAll(String coinSymbol);
}
```

之前工具类实现该接口，并且调用之前静态方法。

```java
@Component
public class CoinSymbolUtils implements  CoinSymbolOperator {

   public ConfigCoinSymbol getSaaSInfoAll(String coinSymbol) {
        return getSaaSInfo(coinSymbol);
   }
}
```



### 第三步 测试mock对象

mock对象我们使用的是**mockito**框架。

```java
public class TaskCenterWithdrawServiceMockTest {
    //待测试的类
    private TaskCenterWithdrawServiceImpl taskCenterWithdrawService;

    private HttpEncryptDecryptEngine httpEncryptDecryptEngine;

    private WithdrawService withdrawService;

    private CoinSymbolOperator coinSymbolOperator;

@Before
public void setup() {
    //创建TaskCenterWithdrawService对象
    httpEncryptDecryptEngine = mock(HttpEncryptDecryptEngine.class);
    withdrawService = mock(WithdrawService.class);
    //mock静态方法拆离的接口在这里需要注入到TaskCenterWithdrawService中
    coinSymbolOperator = mock(CoinSymbolOperator.class);
    taskCenterWithdrawService = new new TaskCenterWithdrawServiceImpl();
    taskCenterWithdrawService.setHttpEncryptDecryptEngine(httpEncryptDecryptEngine);
    taskCenterWithdrawService.setWithdrawService(withdrawService);
    taskCenterWithdrawService.setCoinSymbolOperator(coinSymbolOperator);
}
    
```

   

### 第四步 编写测试方法

测试方法必须要写assertions和你要验证的东西，否则这个单元测试没有意义。这个测试没有用到**assertj**  ，而是使用了**mockito**自带的verify方法验证。

```java
@Test
public void startWithdraw() { 
    //given willReturn 短语帮助我们构造期望的输入和输出，含义是当满足xxx条件时候，发生什么，期望什么结果。
    //当给getWalletUid传入任意int和string时候，调用cryptoAddressService.getWalletUid，期望返回123
    given(cryptoAddressService.getWalletUid(anyInt(), anyString())).willReturn(123);

    //构造期望的返回值
    TransactionWithdrawCrypto transactionWithdrawCrypto = new TransactionWithdrawCrypto();
    transactionWithdrawCrypto.setAddressFrom("alibaba");
    transactionWithdrawCrypto.setFee(new BigDecimal("456.777"));
    transactionWithdrawCrypto.setSymbol("USDT");
    transactionWithdrawCrypto.setAddressTo("baidu");
    transactionWithdrawCrypto.setUid(111111111);

    transactionWithdrawCrypto.setAmount(new BigDecimal("123.444"));
    //构造期望输入和输出
    given(withdrawService.selectByIdAndLock(anyInt())).willReturn(transactionWithdrawCrypto);

    ConfigCoinSymbol ccs = new ConfigCoinSymbol();
    ccs.setTokenBase("BTC");
    ccs.setContractAddress("BTC_ContractAddress");
    //构造期望输入和输出
    given(coinSymbolOperator.from("USDT")).willReturn(ccs);

    Map<String,String> result = new HashMap<>();
    result.put("code", WalletResponseCode.SUCCESS.getCode());
    result.put("message", WalletResponseCode.SUCCESS.getMessage());
    //构造期望输入和输出
    given(httpEncryptDecryptEngine.startWithdraw(anyString(), anyString())).willReturn(JSON.toJSONString(result));

    //和given，willReturn一样的效果
    //when(httpEncryptDecryptEngine.startWithdraw(anyString(), anyString())).thenReturn("111111111");

    //这一步是将之前mock的对象和数据以及构造期望输入和输出串联起来执行。
    taskCenterWithdrawService.startWithdraw("USDT", "BTC", "aaaa", new TransactionWithdrawCrypto());

    //由于该方法是void所以需要验证方法是否被调用.比如断言getWalletUid是否被调用，比如第三方接口返回值不同调用不同的方法
    //来使得代码覆盖率比较高
    verify(this.cryptoAddressService).getWalletUid(111111111, "BTC");
}
```



## 案例二：关联数据库的单元测试

有些测试必须关联数据库或者第三方接口，此时不得不接受使用外部资源这一现实。这时候测试关联数据库的必须保证测试前数据库状态和测试后状态一致。我们来建立一个test fixture来验证一个CRUD的正确性。在每个方法执行前用@BeforeEach中建立Account对象，在integrateTestDataBaseCRUD中测试CRUD方法，在每个方法结束后用@AfterEach清除数据库对象，使得测试前后数据库状态幂等。我曾经遇到一个必须使用第三方资源场景是 本地代码必须调用第三方接口来验证程序，以及在集成测试时候，也主要验证第三方接口，程序本身逻辑很少。这时候就必须使用外部依赖来完成单元测试。

```java
public class AccountServiceTest {
    @Autowired
    private AccountService accountService;
    private Account account;

    @BeforeEach
    void setUp() {
        account = Account.builder().
                balance(new BigDecimal("67.88")).
                type(111).
                uid(445).
                tag("33").
                build();
    }

    @Test
    public void integrateTestDataBaseCRUD() {
        accountService.insert(account);
        long id = account.getId();
        Account accountFind = accountService.get(id);
        accountFind.setBalance(new BigDecimal("366334"));
        accountService.update(accountFind);
        Account accountUpdate = accountService.get(id);
        accountService.delete(id);
        Account accountDelete = accountService.get(id);

        assertAll("test", () -> {
            assertEquals(accountFind.getBalance().stripTrailingZeros().toPlainString(),
                    accountUpdate.getBalance().stripTrailingZeros().toPlainString());
        });
        assertNull(accountDelete);
    }

    @AfterEach
    void tearDown() {
        accountService.delete(id);
    }
}
```



我们可以看到上述两个案例都是先写代码后写单元测试，这样可能导致单元测试很难测试代码，给遗留系统添加单元测试也很繁琐，所以需要从设计层面改进代码，使之更加容易测试和验证。更优秀的做法是实践TDD，这样代码天然可测试。



# 常见问题

**1 单元测试的价值在哪里？** 1  保证代码质量，当然质量保证不仅仅靠单元测试。当你看到队友提交了一些代码，确发现单元测试覆盖率降低了，就知道他的提交可能带来代码质量下降。 2  代码可测试性往往带来灵活的设计。  3  你不仅仅在写单元测试，而是实践自动化测试，实践着CI 

**2  遗留系统很多没有单元测试，我需要补吗？**1  当你修改老代码的时候，加一个单元测试。 2 依赖最多的，访问最多的需要补充。 3 试图在遗留系统上加单元测试很困难，并且使之成为自动化测试，但是需要尝试，新的代码尝试TDD。

**3  我觉得有些情况需要读取数据库，看到数据落库心里才踏实，这时候写单元测试需要连数据库吗？**单元测试不连库，连库的叫集成测试，单元测试验证是逻辑，数据库只是细节实现，你的代码可以脱离SSM，MySQL..... 在实践中你会真正理解解耦的。你的踏实和自信应该建立在独立性和不依赖外界细节上，而不是数据归属地到底是哪里。如果一些测试必须要用数据库，请使用test fixture。保证单元测试前和单元测试后数据库状态一致。

**4  什么时候用Mock或者Stub？** 能不用就不用，最简单的方式验证你的代码是否正确。

**5  DAO层的实体对象需要手动new吗？** 取决于你验证的是什么。随着积累会建立实体对象的测试仓库。

**6  单元测试能检测什么类型bug？** 测不出与数据库交互和第三方接口的BUG，这不是单元测试职责，但是你可以在单元测试中调用第三方，然后发布时候@Disable该测试即可。

**7 为什么不用junit自带的断言，而是第三方断言？** junit断言可读性不好，而且需要自己写断言逻辑，assertXXX，而assertj里面assertThat可以方便断言和真正验证的东西相匹配。

**8 先写测试还是先写代码？** 先写测试的系统天然适合自动化测试，先写代码在写测试，极大可能不写测试了。





这些只是个人观点，实践过程有更好的方法或者理解，可以推翻。单元测试价值不应该被夸大，但也不该被忽视。它是能提高设计和质量的重要工具，因为相信，所以看见。



# 参考书籍

- 《测试驱动开发》
- 《持续集成-软件质量改进和风险降低之道》


---
title: 微信支付公私钥加解密流程
date: 2021-07-22 22:09:52
tags:
  - 公私钥
  - RSA算法
categories:
  - 支付
---

![p3c](/images/wechat-pay.png)

微信支付完整流程如下：

发送方: 私钥签名 公钥加密

接收方: 私钥解密 公钥验签

签名规则：私钥签名，公钥验签。

1 **商户私钥签名**，保证数据商户签名，**微信公钥加密**对原文和签名，得到纯密文，保证商户数据只能由微信私钥解密。

2 **微信私钥解密**，得到商户发送的原数据和签名，用**商户公钥验签**，保证是商户发送的数据。

3 **微信私钥签名**，保证返回值是微信的返回值，用**商户公钥加密**，保证微信返回值只能由商户私钥解密。

4 **商户私钥解密**，得到微信发送的返回值和签名，然后**微信公钥验签**，保证是微信返回的数据。



### openssl生成证书命令

openssl x509 -outform der -in your-cert.pem -out your-cert.crt

openssl genrsa -out ca.key.pem 2048

openssl req -new -key ca.key.pem -out ca.csr

openssl x509 -req -days 1000 -signkey ca.key.pem -in ca.csr -out ca.cer



openssl genrsa -out ca.key.pem 2048

openssl req -new -key ca.key.pem -out ca.csr

openssl x509 -req -days 1000 -signkey ca.key.pem -in ca.csr -out ca.cer

openssl pkcs12  -export -cacerts -inkey ca.key.pem -in ca.cer ca.p12

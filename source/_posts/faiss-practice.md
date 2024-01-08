---
title: 向量检索Faiss实战
date: 2024-01-07 15:25:06
tags:
  - facebook faiss
  - openai
  - embedding
categories:
  - llm
---

# faiss简介

`Faiss is a library for efficient similarity search and clustering of dense vectors。`

官方介绍: Faiss是一个用于高效相似性搜索和密集向量聚类的库。也就是用来实现高效的向量检索。

Faiss主要组件包括：

1. 索引结构：**Flat**（暴力搜索) 、**IVF**(Inverted File)、**IVFPQ**(Inverted File with Product Quantization)、**HNSW**(Hierarchical Navigable Small World)，索引结构可以加速相似性搜索，降低查询时间。
2. 向量编码：**PQ**(Product Quantization)、**OPQ**(Optimized Product Quantization)。编码可以将高维向量映射到低维空间中，同时保持距离的相似性，有助于减少内存占用和计算量。
3. 相似性度量：欧氏距离、内积、Jaccard 相似度等。

Faiss的核心API有：

1. **IndexFactory(d int, description string, metric int)**：用来创建索引，通过维度，索引方法描述，相似性度量来创建索引。
2. **Ntotal()** 索引向量的数量。
3. **Train(x []float32)**  用一组具有代表性的向量训练索引。

4. **Add(x []float32)**，用于创建向量检索集。

5. **Search(x []float32, k int64) (distances []float32, labels []int64, err error)**，x向量在k紧邻进行检索，返回每个查询向量的 k 个最近邻的 ID 以及相应的距离。

如何理解**Add**和**Search**方法呢？**Add**是添加向量，**Search**从向量中检索。比如一篇文章拆分成5个片段，此时调用Add方法生成了5个向量，查询的内容会生成一个查询向量，那么**Search**中**k=2**会返回最近的两个近邻，也就是返回5个向量中的2个向量，那么返回值**distances**是查询向量到返回**2**个向量的距离，返回值**labels**是返回的向量在5个片段中的位置，此时就可以知道返回了那些段。

Faiss的主要流程是：

1. 初始化索引结构，指定相似性度量方法(metric)和编码方法(description)。使用**IndexFactory**。
2. 将原始向量数据添加到索引中。使用**Add**。
3. 对查询向量进行编码，并在索引中搜索与查询向量相似的向量。使用**Search**。
4. 获取搜索结果，并根据需要进行后处理。

# 文档向量化检索设计

如果我们要实现一篇文档的向量化检索该如何设计呢？可以使用mysql和内存缓存作为文档的向量存储，方案可以先将**文档拆分**，然后存储到数据库中，表设计如下：

mysql存储拆分后的文档—— primary_id，edoc_part_content，project_id，embedding

内存缓存存储向量位置到文档主键ID——键：project_id+Ntotal()   值：primary_id

服务启动初始化时候从mysql加载doc表，获取到所有的文档，然后通过Add方法加载到检索集中，每加一次，调用**Ntotal**方法获取当前向量总数，也就是当前向量数组的位置下标，存入内存缓存中，

查询时候，生成查询向量后，调用**Search**方法，获取到检索集位置，然后获取从内存缓存中获取mysql中的主键id，去mysql查询到文档的内容。

# Faiss配置指南

## 相似性计算方法

相似性计算主要有余弦，L1，L2等计算方法。

`InnerProduct   `内积/余弦相似度

`L1` [曼哈顿距离](https://link.zhihu.com/?target=https%3A//blog.csdn.net/hy592070616/article/details/121569933%3Fspm%3D1001.2014.3001.5501)

`L2`    欧氏距离

`Linf` 无穷范数

`Lp`    p范数

`Canberra`    [BC相异度](https://zhuanlan.zhihu.com/p/440130486?utm_id=0)

`BrayCurtis`  [兰氏距离/堪培拉距离](https://link.zhihu.com/?target=https%3A//blog.csdn.net/hy592070616/article/details/122271656)

`JensenShannon`  [JS散度](https://link.zhihu.com/?target=https%3A//blog.csdn.net/hy592070616/article/details/122387046%3Fspm%3D1001.2014.3001.5501)

## 索引方法

索引描述主要是向量检索算法。主要有以下几个：

Flat：最基础的索引结构，比较精确

IVF：Inverted File 倒排文件

PQ：Product Quantization 乘积量化

PCA：Principal Component Analysis 主成分分析

HNSW：Hierarchical Navigable Small World  分层的可导航小世界

| **相似性计算方法** | **索引描述**      | **说明**                                                     |
| :----------------- | :---------------- | :----------------------------------------------------------- |
| InnerProduct       | Flat              | 余弦相似度 暴力检索                                          |
| InnerProduct       | IVF100,Flat       | 余弦相似度   k-means聚类中心为100倒排（IVFx）暴力检索        |
| L2                 | Flat              | 欧式距离 暴力检索                                            |
| InnerProduct       | PQ16              | **余弦相似度 乘积量化** 利用乘积量化的方法，改进了普通检索，将一个向量的维度切成x段，每段分别进行检索，每段向量的检索结果取交集后得出最后的TopK。因此速度很快，而且占用内存较小，召回率也相对较高 |
| L2                 | PCA32,IVF100,PQ16 | 欧式距离 将向量先降维成32维，再用IVF100 PQ16的方法构建索引   |
| L2                 | PCA32,HNSW32      | 欧式距离 处理HNSW内存占用过大的问题                          |
| L2                 | `IVF100,PQ16`     | 欧式距离 **倒排乘积量化**：工业界大量使用此方法，各项指标都均可以接受，利用乘积量化的方法，改进了IVF的k-means，将一个向量的维度切成x段，每段分别进行k-means再检索 |
| 其他               | 其他              | 大家自己枚举调优吧，采用下文测试方法测试是否成功             |





# GoLang代码例子

**faiss**本身用**C++**实现，这里使用**go-faiss**来实现例子，**embeding**获取通过**openai**的接口实现。

```golang
package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/rand"

	gofaiss "github.com/DataIntelligenceCrew/go-faiss"
	"github.com/sashabaranov/go-openai"
	"github.com/spf13/cast"
)

const (
	AuthToken = "openai的token"
)

var MetricTypeMap = map[string]int{
	"InnerProduct":  gofaiss.MetricInnerProduct,  // 0
	"L2":            gofaiss.MetricL2,            // 1
	"L1":            gofaiss.MetricL1,            // 2
	"Linf":          gofaiss.MetricLinf,          // 3
	"Lp":            gofaiss.MetricLp,            // 4
	"Canberra":      gofaiss.MetricCanberra,      // 20
	"BrayCurtis":    gofaiss.MetricBrayCurtis,    // 21
	"JensenShannon": gofaiss.MetricJensenShannon, // 22
}

type FaissReq struct {
	IsDemo      bool      `json:"is_demo"`
	DBSize      int       `json:"db_size"`
	QuerySize   int       `json:"query_size"`
	KNearest    int64     `json:"k_nearest"`
	Question    string    `json:"question"`
	Model       string    `json:"model"`
	Embedding   []float32 `json:"embedding"`
	Dimension   int       `json:"dimension"`   // 维度
	Description string    `json:"description"` // 索引描述
	Metric      string    `json:"metric"`      // 相似性度量方法
}

type FaissRsp struct {
	IsTrained bool  `json:"is_trained"`
	Ntotal    int64 `json:"n_total"`
	Dimension int   `json:"dimension"`
}

type EmbeddingReq struct {
	Prompt string `json:"prompt"`
	Model  string `json:"model"`
}

type EmbeddingRsp struct {
	Embedding []float32 `json:"embedding"`
	Time      string    `json:"time"`
}

func QueryFaiss(req FaissReq) (rsp FaissRsp, err error) {
	log.Printf("all metrics is:%+v", MetricTypeMap)
	if req.IsDemo {
		d := req.Dimension  // 向量维度
		nb := req.DBSize    // 全部数据大小
		nq := req.QuerySize // 

    // 所有数据的向量
		xb := make([]float32, d*nb)
		// 查询数据的向量
    xq := make([]float32, d*nq)

    // 初始化全部数据
		for i := 0; i < nb; i++ {
			for j := 0; j < d; j++ {
				xb[i*d+j] = rand.Float32()
			}
			xb[i*d] += float32(i) / 1000
		}

    // 初始化查询数据
		for i := 0; i < nq; i++ {
			for j := 0; j < d; j++ {
				xq[i*d+j] = rand.Float32()
			}
			xq[i*d] += float32(i) / 1000
		}

    // 初始化Faiss
		indexImpl, err := gofaiss.IndexFactory(d, req.Description, MetricTypeMap[req.Metric])
		if err != nil {
			log.Printf("IndexFactory err:%+v", err)
			return FaissRsp{}, err
		}
		defer indexImpl.Delete()

    // 训练全部数据
		trainErr := indexImpl.Train(xb)
		if trainErr != nil {
			log.Printf("Train err:%+v", trainErr)
			return FaissRsp{}, err
		}
    // 将全部数据加入Faiss中
		addErr := indexImpl.Add(xb)
		if err != nil {
			log.Printf("addErr err:%+v", addErr)
			return FaissRsp{}, err
		}
		k := int64(4)

		// 合法性检查，用全部数据的前5*维度个
		dist, ids, err := indexImpl.Search(xb[:5*d], k)
		if err != nil {
			log.Printf("Search err:%+v", err)
			return FaissRsp{}, err
		}
		log.Printf("Search dist:%+v,ids:%+v", dist, ids)

		fmt.Println("ids=")
		for i := int64(0); i < 5; i++ {
			for j := int64(0); j < k; j++ {
				fmt.Printf("%5d ", ids[i*k+j])
			}
			fmt.Println()
		}

		fmt.Println("dist=")
		for i := int64(0); i < 5; i++ {
			for j := int64(0); j < k; j++ {
				fmt.Printf("%7.6g ", dist[i*k+j])
			}
			fmt.Println()
		}

		// 通过查询数据xq进行向量检索
		ps, err := gofaiss.NewParameterSpace()
		if err != nil {
			log.Printf("NewParameterSpace err:%+v", err)
			return FaissRsp{}, err
		}
		defer ps.Delete()

		if err := ps.SetIndexParameter(indexImpl, "nprobe", 10); err != nil {
			log.Printf("SetIndexParameter err:%+v", err)
			return FaissRsp{}, err
		}

		_, ids, err = indexImpl.Search(xq, k)
		if err != nil {
			log.Printf(" indexImpl.Search Last err:%+v", err)
			return FaissRsp{}, err
		}

		fmt.Println("ids (last 5 results)=")
		for i := int64(nq) - 5; i < int64(nq); i++ {
			for j := int64(0); j < k; j++ {
				fmt.Printf("%5d ", ids[i*k+j])
			}
			fmt.Println()
		}
		return FaissRsp{}, nil
	}

	indexImpl, err := gofaiss.IndexFactory(req.Dimension, req.Description, MetricTypeMap[req.Metric])
	if err != nil {
		log.Printf("IndexFactory error:%+v,req:%+v", err, req)
		return FaissRsp{}, err
	}

	var embeddingArray []float32
	if len(req.Question) != 0 {
		embedding, embeddingErr := Embedding(context.Background(), EmbeddingReq{Prompt: req.Question, Model: req.Model})
		if embeddingErr != nil {
			log.Printf("Embedding err:%+v", embeddingErr)
			return FaissRsp{}, embeddingErr
		}
		embeddingArray = embedding.Embedding
	} else {
		embeddingArray = req.Embedding
	}

	log.Printf("embedding is:%s", jsonString(embeddingArray))

	err = indexImpl.Train(embeddingArray)
	if err != nil {
		log.Printf("indexImpl.Train error:%+v,req:%+v", err, req)
		return FaissRsp{}, err
	}
	err = indexImpl.Add(embeddingArray)
	if err != nil {
		log.Printf("indexImpl.Add error:%+v,req:%+v", err, req)
		return FaissRsp{}, err
	}

	dist, ids, err := indexImpl.Search(embeddingArray, req.KNearest)
	if err != nil {
		log.Printf("Search err:%+v", err)
		return FaissRsp{}, err
	}
	log.Printf("Search dist:%s,\n ids:%s", jsonString(dist), jsonInt64String(ids))

	return FaissRsp{IsTrained: indexImpl.IsTrained(), Ntotal: indexImpl.Ntotal(), Dimension: indexImpl.D()}, nil
}

func jsonString(data []float32) string {
	marshal, _ := json.Marshal(data)
	return string(marshal)
}

func jsonInt64String(data []int64) string {
	marshal, _ := json.Marshal(data)
	return string(marshal)
}

// Embedding 根据openai获取embedding
func Embedding(ctx context.Context, req EmbeddingReq) (rsp EmbeddingRsp, err error) {

	var model openai.EmbeddingModel
	if len(req.Model) == 0 {
		model = openai.AdaEmbeddingV2
	} else {
		model = openai.EmbeddingModel(cast.ToInt(req.Model))
	}

	cfg := openai.DefaultConfig(AuthToken)
	cfg.BaseURL = "https://api.aiproxy.io/v1"
	client := openai.NewClientWithConfig(cfg)
	resp, err := client.CreateEmbeddings(ctx, openai.EmbeddingRequest{
		Input: req.Prompt,
		Model: model,
	})
	if err != nil {
		log.Printf("Embedding error: %v,question:%s,model:%s,resp:%+v", err, req.Prompt, model)
		return rsp, err
	}

	if len(resp.Data) > 0 {
		return EmbeddingRsp{
			Embedding: resp.Data[0].Embedding,
			Time:      "",
		}, nil
	}
	return rsp, errors.New("没有Embeddings")
}
```

# 参考

https://github.com/facebookresearch/faiss

https://github.com/DataIntelligenceCrew/go-faiss

https://zhuanlan.zhihu.com/p/357414033

https://guangzhengli.com/blog/zh/vector-database/

https://faiss.ai/index.html

https://github.com/sashabaranov/go-openai/blob/master/embeddings.go

https://platform.openai.com/docs/guides/embeddings

https://openai.com/blog/new-and-improved-embedding-model

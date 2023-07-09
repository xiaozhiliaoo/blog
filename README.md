# blog

我的博客源码

## 部署

1. 首先需要安装nodejs。
2. 然后安装hexo，命令：npm install -g hexo-cli。
3. 启动，hexo clean & hexo g & hexo s，可见脚本：start.sh。
4. 部署，hexo clean & hexo g & hexo d，可见脚步：deploy.sh。

hexo d 部署到了https://github.com/xiaozhiliaoo/xiaozhiliaoo.github.io这个项目

## 目录说明

整个站点的目录：[source](source)

文章的目录：[source/_posts](source/_posts)

主题的目录：[themes](themes)


## 新建文章

hexo new xxx

## 站点的配置

_config.yaml

站点主题配置在theme: next

## 主题的配置

在themes下主题的_config.yaml里面

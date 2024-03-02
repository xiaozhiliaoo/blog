# blog

我的博客源码，博客访问地址：[https://xiaozhiliaoo.github.io/](https://xiaozhiliaoo.github.io/)

## 部署

1. 首先需要安装nodejs。
2. 然后安装hexo，命令：**npm install -g hexo-cli**。
3. 将项目全部克隆到某个文件夹下。
4. 启动，**hexo clean & hexo g & hexo s**，可见脚本：**start.sh**。
5. 部署，**hexo clean & hexo g & hexo d**，可见脚步：**deploy.sh**。
6. 部署完之后将所有改动提交到blog仓库即可。执行 **sh up.push.git.sh**

hexo d 将生成后的博客源码部署到了[https://github.com/xiaozhiliaoo/xiaozhiliaoo.github.io](https://github.com/xiaozhiliaoo/xiaozhiliaoo.github.io) 这个项目。

博客访问地址：[https://xiaozhiliaoo.github.io/](https://xiaozhiliaoo.github.io/)

## 目录说明

整个站点的目录：[source](source)

文章的目录：[source/_posts](source/_posts)

主题的目录：[themes](themes)


## 新建文章

hexo new xxx

## 站点的配置

_config.yaml

站点主题配置在theme: next


## 安装主题

在themes下git clone主题源码即可，需要删除.git目录，否则提交不到blog仓库。然后在[_config.yml](_config.yml) 配置主题名字，也就是目录的名字


## 主题的配置

在themes下主题的_config.yaml里面

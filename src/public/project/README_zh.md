# Samizdat 项目

在言论自由被禁止的前东欧集团，人们使用其他方法。通过手工复制和分发文本的地下
草根运动被称为地下出版物（samizdat）。

* 了解[使用和安装](installation/)
* 如何[贡献](../contribute/)

### 亮点

* 国际化支持
* 人类可读格式——YAML 和 Markdown
* 速度优化——自动 WebP 图像，智能缓存生成的内容，最小化
* 美观打印和语义化 HTML5
* Mojolicious 智能模板
* 自动一列或两列布局，带连接的侧面板
* [轻松内联 SVG 图像](./icons/)的辅助功能
* [国家数据](../../country/)的辅助功能

### 目录结构

* bin - 脚本
* lib - Perl 模块
  * Samizdat
    * Command - 为 samizdat 命令添加选项的 Perl 模块
* public - 静态文件。Markdown。处理后的文件也作为缓存内容放在这里
* t - 测试套件
* templates - 模板、布局和较小的块

public 目录中的文件是进入磁盘镜像（ISO 格式）以供本地查看的内容。
也可以使用 Web 服务器提供超快速的内容。希望我能找到一个 BitTorrent
解决方案来流式传输视频。Fakenews.com 将使用 Samizdat 一段时间，并定期更新。

### 个人使用盗版

不应将任何媒体材料添加到此存储库。将代码视为一种工具，让您在孤岛上度过时光时
可以随身携带一些您最喜欢的内容。
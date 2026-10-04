# 更新日志

本文件记录 Explore iOS 客户端的所有重要变更。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/spec/v2.0.0.html)。

[English](CHANGELOG.md)

## [未发布]

### 新增

- 和网站一样，点开文章时先显示一个不到一秒的过渡页，写着博客名和文章标题，进度条走完后再打开 Safari 视图（或你偏好的 Safari）。在「我的」里关掉「显示过渡页」，就会直接打开文章。

## [0.1.0] - 2026-10-04

Explore iOS 客户端的第一个版本：[Explore](https://github.com/kite-plus/explore) 在 iPhone 和 iPad 上的原生客户端，用 SwiftUI 编写，面向 iOS 26，围绕液态玻璃设计。默认读取 explore.kite.plus，也可以连接其他运行 0.1.6 或更新版本的 Explore 服务器。目前还没有上架 App Store 或 TestFlight，用 Xcode 构建的方法见 README。

### 新增

- 发现：和网站一样，「最新」「推荐」「订阅」三条文章流做成标签，文章按发布日期分组，可按博客语言和标签筛选。每篇文章都在作者自己的网站打开：默认用 App 内的 Safari 视图，也可以改用 Safari，链接只加上 `utm_source`。
- 博客：按最近更新排列的博客目录，每个博客都有自己的页面；可以搜索博客和标签。
- 账号：登录或创建账号，订阅博客，管理订阅列表并导出为 OPML，用 DNS 记录认领自己的博客，提交博客并跟踪审核进度，报告问题。
- 链接检测：每篇文章旁显示 Explore 最近一次检测链接的结果，从未检测过的文章可以当场检测。
- 「最新文章」小组件：主屏幕三种尺寸，锁定屏幕两种。
- 英文和简体中文界面。文章标题和摘要保持作者原文的语言。
- 没有统计，不请求任何第三方；阅读不需要账号。

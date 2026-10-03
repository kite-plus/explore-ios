<h1 align="center">Explore for iOS</h1>

<p align="center">在 iPhone 和 iPad 上发现大家在写什么。</p>

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

[Explore](https://github.com/kite-plus/explore) 的原生客户端：独立博客的最新文章汇成一条信息流。用 Swift 和 SwiftUI 编写，面向 iOS 26，围绕 Liquid Glass（液态玻璃）设计。和网站一样，App 只展示标题、日期、简短摘要和缩略图，每篇文章都在作者自己的网站打开。

## 功能

- **发现**：和网站一样，三条文章流做成标签：所有收录博客的最新文章、推荐文章，以及你订阅的博客。文章按发布日期分组，可按博客语言和标签筛选，支持下拉刷新和无限翻页。每篇文章旁显示 Explore 最近一次链接检测的结果，从未检测过的文章可以当场检测。
- **订阅**：订阅博客，在发现页的「订阅」标签里追更；订阅列表在「我的」里管理，并可导出为 OPML 带到任何 RSS 阅读器。
- **博客**：按最近更新排列的博客目录，每个博客都有自己的页面，展示订阅源、文章、语言和博客系统。
- **搜索**：发现页顶部的搜索框可以浏览 Explore 的标签，并按名称、地址、简介即时搜索博客；博客目录顶部也有自己的搜索框。
- **我的**：登录或创建账号，修改名称和密码，删除账号，用 DNS 记录认领自己的博客，提交博客并跟踪审核进度，还可以连接其他 Explore 服务器。
- **阅读**：文章默认在 App 内的 Safari 视图中打开，也可以改为直接用 Safari 打开，并可开启阅读器视图。链接和网站一样只加上 `utm_source`，不添加任何其他内容。
- **小组件**：在主屏幕（三种尺寸）和锁定屏幕上显示最新文章，可以只看中文或英文博客。点一下文章，就在作者的网站打开。
- **语言**：英文和简体中文。文章标题和摘要始终保持作者原文的语言。

## 液态玻璃

App 全程使用系统自带的 Liquid Glass，而不是模仿它：

- 始终展开的玻璃标签栏，三个栏目一直看得到；
- 发现页的文章流标签和玻璃「筛选」按钮停在搜索框下面，滚动时由系统的边缘效果衬底；筛选打开一个面板，里面是语言开关和带图标的标签方块；
- 博客页的玻璃操作按钮，博客卡片和标签方块带缩放转场，链接检测结果显示在玻璃弹出框里；
- 用 Icon Composer 制作的分层 App 图标，带浅色、深色和着色版本。

## 隐私

App 没有任何统计，也不向第三方发出请求：文章缩略图和博客图标都来自 Explore 服务器。阅读不需要账号，也不发送 Cookie。登录后，会话令牌保存在钥匙串里，只发给签发它的服务器。文章链接从不经过跳转页。

## 构建

需要 Xcode 26 或更新版本。打开 `Explore.xcodeproj`，选择 `Explore` scheme，在 iOS 26 或更新版本的 iPhone、iPad 模拟器上运行。要在真机上运行，把 `Config/Local.xcconfig.example` 复制为 `Config/Local.xcconfig`，填上你的 `DEVELOPMENT_TEAM`；如果不能使用 `plus.kite.explore` 这个标识，同时修改 `APP_BUNDLE_ID`，小组件的标识会跟着变。这个文件不进 git，项目文件本身不用改。

项目没有第三方依赖。App 在 `Explore/`，小组件在 `ExploreWidget/`，两者共用的代码在 `Shared/`：

| 目录 | 内容 |
|---|---|
| `Explore/App` | App 入口、标签页、导航、深度链接和共享的 App 状态 |
| `Explore/Core` | API 客户端、图片加载、钥匙串、格式化和链接处理 |
| `Explore/Design` | 颜色、博客头像和共用的玻璃组件，包括主要按钮的黑白样式 |
| `Explore/Features` | 每个功能一个目录：发现、订阅、博客、搜索、账号和提交 |
| `Explore/Resources` | 资源目录、App 图标、字符串目录和隐私清单 |
| `ExploreWidget` | “最新文章”小组件 |
| `Shared` | API 数据模型、时间解析、界面语言和头像颜色 |

小组件固定读取 explore.kite.plus；在 App 里切换的服务器只对 App 生效。

客户端遵循 Explore 的 [docs/design/api.md](https://github.com/kite-plus/explore/blob/main/docs/design/api.md) 中描述的接口。

## 测试

单元测试使用 Swift Testing，覆盖数据解码、时间解析、链接标记、头像颜色、OPML 导出和深度链接：

```bash
xcodebuild test -project Explore.xcodeproj -scheme Explore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## 深度链接

`explore://` 链接可以直接打开某个页面，路径和网站相同：`explore://blogs/{host}`、`explore://topics/{slug}`、`explore://submissions/{id}`、`explore://submit`、`explore://sign-in`、`explore://recommended`、`explore://following`、`explore://search` 和 `explore://about`。

## 许可证

Explore for iOS 采用 [Apache License 2.0](LICENSE) 授权。

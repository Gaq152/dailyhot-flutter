<p align="center">
  <img src="assets/images/app_icon.png" alt="DailyHot Logo" width="120" height="120">
</p>

<h1 align="center">📱 DailyHot - 每日热点聚合</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.35+-blue.svg" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.9+-blue.svg" alt="Dart">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/github/v/release/Gaq152/dailyhot-flutter" alt="Release">
</p>

<p align="center">
  基于 Flutter 开发的 Android 每日热点聚合应用<br>
  聚合 56 个热门平台的实时热榜数据，一站式浏览全网热点
</p>

---

## ✨ 功能特性

### 📊 热榜聚合
- **56 个热门平台**：哔哩哔哩、抖音、微博、知乎、百度、快手、GitHub 等
- **实时更新**：支持手动刷新，获取最新热点数据
- **智能缓存**：本地缓存机制，离线也能浏览
- **榜单排序**：支持自定义榜单显示顺序

### 🎨 用户体验
- **明暗主题**：支持浅色/深色模式，跟随系统自动切换
- **流畅动画**：卡片渐入、列表逐条加载等精美动画效果
- **字体调节**：支持调整列表文字大小，适应不同阅读习惯
- **快速滚动**：智能滚动按钮，快速到达页面顶部/底部
- **错误处理**：友好的错误提示和重试机制

### 🔗 链接处理
- **抖音深度集成**：自动获取视频 ID，支持直接唤起抖音 APP
- **浏览器降级**：无抖音 APP 时自动使用浏览器打开
- **外部链接**：支持在浏览器中打开所有榜单链接

### 🔄 自动更新
- **智能检查**：启动时异步检查 + 运行时6小时定期检查，及时获取版本更新
- **红点提醒**：检测到新版本后，设置图标和"检查更新"行显示醒目红点
- **持久化记忆**：点击"稍后"后信息保存，重启应用红点依然显示
- **更新弹窗**：显示版本号、更新内容和一键下载入口
- **自动构建**：GitHub Actions 自动构建并发布签名 APK
- **自由控制**：设置中可开关自动检查功能

## 📱 支持的平台

<details>
<summary><b>查看完整榜单列表（56个）</b></summary>

| 平台 | 平台 | 平台 | 平台 |
|------|------|------|------|
| 哔哩哔哩 | 抖音 | 百度 | 百度贴吧 |
| CSDN | 微博 | 知乎 | 36氪 |
| 少数派 | IT之家 | 稀土掘金 | 今日头条 |
| 澎湃新闻 | 腾讯新闻 | 豆瓣电影 | 原神 |
| LOL | 崩坏：星穹铁道 | 网易新闻 | 微信读书 |
| 豆瓣讨论小组 | NGA | HelloGitHub | 简书 |
| 知乎日报 | 51CTO | AcFun | 酷安 |
| 地震速报 | 历史上的今天 | 崩坏3 | 虎扑 |
| 虎嗅 | 爱范儿 | IT之家喜加一 | NodeSeek |
| 新浪新闻 | 新浪 | V2EX | 天气预警 |
| 吾爱破解 | 数字尾巴 | GameRes | 极客公园 |
| GitHub | 果壳 | Hacker News | HostLoc |
| 快手 | Linux.do | 米游社 | 水木社区 |
| 纽约时报 | Product Hunt | 什么值得买 | 游研社 |

</details>

## 🚀 快速开始

### 环境要求

- Flutter SDK: `>= 3.35.5`
- Dart SDK: `>= 3.9.2`
- Android SDK: `>= 21 (Android 5.0)`

### 安装依赖

```bash
# 克隆仓库
git clone https://github.com/Gaq152/dailyhot-flutter.git
cd dailyhot-flutter

# 安装依赖
flutter pub get
```

### 运行应用

```bash
# 开发模式运行
flutter run

# 或指定设备
flutter run -d <device_id>
```

### 构建 APK

```bash
# 构建 Release 版本
flutter build apk --release

# APK 文件位置
# build/app/outputs/apk/release/dailyhot.apk
```

## 🛠️ 技术栈

### 核心框架
- **Flutter 3.35+** - 跨平台 UI 框架
- **Dart 3.9+** - 编程语言

### 状态管理
- **Riverpod 2.6+** - 响应式状态管理

### 网络请求
- **Dio 5.4+** - HTTP 客户端
- **Pretty Dio Logger** - 网络日志

### 本地存储
- **Hive 2.2+** - 轻量级数据库
- **Shared Preferences** - 键值对存储

### 路由导航
- **Go Router 13.2+** - 声明式路由

### UI 组件
- **Cached Network Image** - 图片缓存
- **Shimmer** - 骨架屏动画
- **URL Launcher** - 外部链接
- **WebView Flutter** - 网页浏览
- **Android Intent Plus** - Android 意图调用
- **Package Info Plus** - 应用信息

## 📦 项目结构

```
lib/
├── core/                    # 核心模块
│   ├── constants/          # 常量配置
│   ├── utils/              # 工具类
│   └── theme/              # 主题配置
├── data/                   # 数据层
│   ├── datasources/        # 数据源
│   │   ├── local/         # 本地数据源（Hive）
│   │   └── remote/        # 远程数据源（API）
│   ├── models/            # 数据模型
│   ├── repositories/      # 数据仓库
│   └── services/          # 业务服务
│       └── update_service.dart  # 自动更新服务
├── presentation/          # 表现层
│   ├── pages/            # 页面
│   │   ├── home/        # 首页
│   │   ├── list/        # 榜单详情
│   │   └── settings/    # 设置页
│   ├── providers/       # Riverpod 提供者
│   └── widgets/         # 通用组件
└── main.dart            # 应用入口
```

## ⚙️ 配置说明

### 修改后端 API 地址

编辑 `lib/core/constants/app_constants.dart`：

```dart
class AppConstants {
  // API 基础地址
  static const String baseUrl = 'https://your-api-domain.com';

  // 应用信息
  static const String appName = 'DailyHot';
  static const String appVersion = '1.0.0';
}
```

### 自定义榜单显示

编辑 `lib/core/constants/hot_list_data.dart`，调整 `show` 和 `order` 属性：

```dart
HotListCategory(
  name: 'bilibili',
  label: '哔哩哔哩',
  order: 0,
  show: true,  // 是否显示
),
```

## 🔄 CI/CD 自动化

### 发布新版本流程

项目采用 CHANGELOG 驱动的发布流程，步骤如下：

#### 1. 更新 CHANGELOG.md

在 `CHANGELOG.md` 中添加新版本的更新内容：

```markdown
## [1.0.1] - 2025-10-03

### 新增功能
- ✨ 添加了某某新功能
- 🎨 优化了某某界面

### 问题修复
- 🐛 修复了某某问题
- 🔧 修复了某某 Bug
```

#### 2. 更新版本号

编辑 `pubspec.yaml`：

```yaml
version: 1.0.1+2  # 主版本.次版本.修订号+构建号
```

#### 3. 提交代码

```bash
git add .
git commit -m "chore: 发布 v1.0.1"
git push
```

#### 4. 创建并推送标签

```bash
git tag v1.0.1
git push origin v1.0.1
```

#### 5. 自动构建发布

推送标签后，GitHub Actions 会自动：
- ✅ 从 CHANGELOG.md 提取对应版本的更新内容
- ✅ 构建 Release APK（`dailyhot.apk`）
- ✅ 生成 SHA256 校验值
- ✅ 创建 GitHub Release 并上传 APK
- ✅ 使用 CHANGELOG 内容作为 Release 说明

### 工作流配置

查看 `.github/workflows/build-release.yml` 了解详细配置。

### 版本管理规范

遵循 [语义化版本](https://semver.org/lang/zh-CN/)：
- **主版本号（1.x.x）**：重大功能变更或不兼容的修改
- **次版本号（x.1.x）**：向下兼容的功能新增
- **修订号（x.x.1）**：向下兼容的问题修正

## 📸 应用截图

<!-- 建议添加应用截图 -->
_待添加_

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

本项目基于以下开源项目：
- [DailyHotApi](https://github.com/Gaq152/DailyHotApi) - 后端 API 服务

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

## 👨‍💻 开发者

**gaq**

- GitHub: [@Gaq152](https://github.com/Gaq152)
- 项目仓库: [dailyhot-flutter](https://github.com/Gaq152/dailyhot-flutter)

---

<p align="center">
  如果这个项目对你有帮助，请给一个 ⭐️ Star 支持一下！
</p>

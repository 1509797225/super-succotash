# JellyTodo

`JellyTodo` 是一个原生 iOS 待办与番茄钟应用，主打大字号、大卡片、超大圆角和轻拟态果冻质感。项目以快速落地 MVP 为目标，当前功能全部本地运行，不依赖登录、网络或服务端。

GitHub 仓库：`1509797225/super-succotash`

## 产品特性

- `Plan`：展示可折叠任务组，任务组下可继续新增 item，item 可左滑加入 Today。
- `Today`：展示今日待办，支持新增、编辑、删除、完成状态切换。
- `Set`：本地个人资料、主题、偏好设置与关于信息。
- `Task Sheet`：轻点任务打开底部半模态操作面板，可进入专注、编辑、删除、查看已专注时长。
- `Focus`：任务级番茄钟专注页，支持正向/倒向计时、暂停、继续、停止。
- `Landscape Focus`：Focus 页支持手动横竖屏切换，横屏隐藏底部 TabBar。
- `Immersive Mode`：横屏下可进入沉浸式，只保留倒计时和退出按钮。
- `Pomodoro Stats`：通过 Today 右上角饼图入口查看 3D 饼图、竖状占比图和按 Plan 聚合的番茄统计。
- `Themes`：支持灰度基调以及粉色、蓝色、绿色等主题基调。
- `Language`：支持应用内 English / 简体中文切换，设置后本地持久化。

## 技术栈

- 平台：iOS 16+
- UI：SwiftUI
- 架构：MVVM + 单向数据流
- 导航：NavigationStack + TabView
- 存储：UserDefaults + Codable
- 图表：自绘 Donut / 3D Pie 组件
- 工程：单 Target 原生 Xcode iOS App

## 项目结构

```text
JellyTodo
├── Core
│   ├── Models
│   ├── Store
│   ├── Storage
│   ├── Theme
│   └── Utils
├── Features
│   ├── Month
│   ├── PomodoroStats
│   ├── Set
│   └── Today
├── Resources
└── Shared
    └── Components
```

## 本地运行

1. 使用 Xcode 打开 `JellyTodo.xcodeproj`。
2. 选择 `JellyTodo` scheme。
3. 选择 iPhone Simulator 或已连接真机。
4. 点击 Run。

命令行构建：

```bash
xcodebuild -project JellyTodo.xcodeproj \
  -scheme JellyTodo \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## 开发原则

`ios_todo_app_technical_plan.md` 是本项目唯一产品与技术真相源。

- 改功能范围、页面结构、数据模型、主题规则、交互规则时，先更新 `ios_todo_app_technical_plan.md`，再改代码。
- 只改内部实现且不影响外部行为时，可以只改代码。
- 每次里程碑提交前，检查核心文档与实现是否一致。
- `README.md` 只负责项目介绍、运行方式和协作提示，不承载完整 PRD。

## Git 提交作者

为了让 GitHub Contribution Graph 正确统计贡献，当前仓库建议使用已绑定并验证过的 GitHub 邮箱：

```bash
git config user.name "zhang"
git config user.email "zyl1509797225@gmail.com"
```

如果贡献图没有显示，请检查 GitHub `Settings -> Emails` 中该邮箱是否已添加且为 `Verified`。

## 当前范围

本期不包含：

- 账号登录或注册
- 云同步
- 多端同步
- 通知推送
- Widget
- 服务端资料系统

所有任务、设置与番茄钟记录均保存在本地，卸载 App 后数据清空。

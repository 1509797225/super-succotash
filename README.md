# JellyTodo

`JellyTodo` 是一个原生 iOS 待办与番茄钟应用，主打大字号、大卡片、超大圆角和轻拟态果冻质感。项目以快速落地 MVP 为目标，当前以本地优先为核心，已接入 staging 云同步与 Pro 云备份能力。

GitHub 仓库：`1509797225/super-succotash`

## 产品特性

- `Plan`：展示可折叠任务组，任务组下可继续新增 item，item 可左滑加入 Today。
- `Today`：展示今日待办，支持新增、编辑、删除、完成状态切换。
- `Set`：本地个人资料、主题、偏好设置、订阅状态、备份与同步。
- `Account`：Set 页支持 Sign in with Apple 一期接入，登录态写入 Keychain；DEBUG 下提供 Mock Staging Login 方便免费开发者账号阶段联调。
- `Task Sheet`：轻点任务打开底部半模态操作面板，可进入专注、编辑、删除、查看已专注时长。
- `Focus`：任务级番茄钟专注页，支持正向/倒向计时、暂停、继续、停止。
- `Landscape Focus`：Focus 页支持手动横竖屏切换，横屏隐藏底部 TabBar。
- `Immersive Mode`：横屏下可进入沉浸式，只保留倒计时和退出按钮。
- `Pomodoro Stats`：通过 Today 右上角饼图入口查看 3D 饼图、时间序列柱状图和番茄统计。
- `Themes`：支持灰度基调以及粉色、蓝色、绿色等主题基调。
- `Language`：支持应用内 English / 简体中文切换，设置后本地持久化。

## 技术栈

- 平台：iOS 16+
- UI：SwiftUI
- 架构：MVVM + 单向数据流
- 导航：NavigationStack + TabView
- 存储：SQLite + UserDefaults/Codable 回滚备份
- 云端：Node.js + PostgreSQL staging API
- 图表：自绘 Donut / 3D Pie 组件
- 工程：原生 Xcode iOS App + `JellyTodoTests` 单元测试 Target

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

命令行测试：

```bash
xcodebuild test -project JellyTodo.xcodeproj \
  -scheme JellyTodo \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## 开发原则

`ios_todo_app_technical_plan.md` 是本项目唯一产品与技术真相源。

- 改功能范围、页面结构、数据模型、主题规则、交互规则时，先更新 `ios_todo_app_technical_plan.md`，再改代码。
- 改本地数据库、云同步、云测数据、部署环境时，同步更新 `data_management_and_cloud_sync_plan.md`。
- 改账号登录、匿名迁移、token、订阅账号绑定时，同步更新 `account_auth_integration_plan.md`。
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

本期暂不包含：

- 密码账号登录或注册
- 多端同步
- 通知推送
- Widget
- 服务端资料系统

Free 数据只保存在本机，卸载 App 后随沙盒清空；Pro 路线已接入云同步、云端备份点和显式云端恢复的一期能力。

## 数据与云同步规划

当前版本已开始迁移到本地 SQLite，并暂时保留 `UserDefaults + Codable` 作为回滚备份。后续数据层升级路线已记录在：

```text
data_management_and_cloud_sync_plan.md
```

推荐方向为 `SQLite + GRDB` 本地数据库、`Local-first` 增量同步、云端 `PostgreSQL + Backend API`，并先部署 staging 云测环境。部署优先用 Docker Compose；如果服务器拉取 Docker Hub 镜像超时，则使用 Ubuntu 原生部署脚本。

未来商业化按 `Free / Pro` 两档设计：Free 仅本机 SQLite 持久化，卸载 App 后数据随沙盒删除；Pro 开启云备份、云恢复和多设备同步。当前已具备 StoreKit 2 端侧骨架、staging 交易同步接口、云端权益闸口、前台自动同步和云端恢复点；真实订阅还需要在 App Store Connect 创建商品并接入 App Store Server API 级交易验签。

账号接入路线记录在：

```text
account_auth_integration_plan.md
```

当前采用 `Sign in with Apple + 自建轻量认证层`，用户数据、订阅权益和云同步归属仍由 JellyTodo 后端管理。Apple 登录一期代码已接入，但免费开发者账号阶段默认不启用 Apple 登录 entitlement，先用 DEBUG 下的 Mock Staging Login 联调；完整同步接口 token 化仍在后续阶段。

开发期调试浮层已支持查看本地数据库摘要，并手动 mock `Free / Pro` 权益状态；mock 结果会写入本机 SQLite 的 `entitlement_state`。

云测代码已放在：

```text
cloud/
```

本地或服务器部署入口：

```bash
cd cloud
cp .env.example .env
docker compose -f docker-compose.staging.yml up -d --build
```

国内云服务器 Docker 镜像拉取不稳定时，在服务器仓库根目录执行：

```bash
APP_USER=ubuntu ./cloud/scripts/deploy_native_ubuntu.sh
```

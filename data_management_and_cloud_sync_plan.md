# JellyTodo 数据管理与云同步技术方案

## 1. 文档定位

本文档定义 `JellyTodo` 后续数据管理、本地数据库迁移、云端同步和云测数据部署方案。

治理规则：

- `ios_todo_app_technical_plan.md` 仍是项目唯一产品与技术真相源。
- 本文档是核心技术方案的数据专项附录，涉及数据模型、存储、同步、云端环境的改动必须同步更新本文档。
- 代码实现变更如果影响字段、表结构、同步协议、云测数据规则，必须先更新本文档，再改代码。

## 2. 当前状态

当前 App 使用：

- 本地存储：SQLite 第一阶段 + `UserDefaults + Codable` 回滚备份
- 状态入口：`AppStore`
- 数据范围：Plan、Today、TodoItem、PomodoroSession、UserProfile、AppSettings、调试插桩数据
- 云端能力：staging API 已部署，端侧 Debug 入口支持健康检查和只读拉取云测数据
- 账号体系：暂无
- 订阅体系：暂无，后续按 Free 本地版 / Pro 云同步版设计

当前方案已经从纯 `UserDefaults` 进入 SQLite 迁移第一阶段，但仍未完成 Repository、change_logs 和正式同步闭环。

主要风险：

- 第一阶段 SQLite 仍采用整表替换保存，尚未充分利用增量 SQL 写入。
- 尚未建立 Repository 层，页面状态和持久化边界还可以继续拆清楚。
- 尚未写入 `change_logs`，不能直接做正式增量同步。
- 不方便做云同步冲突处理。
- 数据结构变化后仍需要更系统的迁移版本管理。

## 3. 目标架构

长期目标采用 `Local-first` 架构：

```text
iOS App
  ↓
Local SQLite Database
  ↓
Repository / AppStore
  ↓
Sync Engine
  ↓ HTTPS API
Backend Server
  ↓
PostgreSQL
```

原则：

- App 本地数据永远优先可用，离线也能完整使用。
- Free 数据只保存在本机 SQLite，正常重启不丢失，卸载 App 后随沙盒删除而丢失。
- Pro 数据采用本机 SQLite + 云端同步，支持云备份、云恢复和多设备同步。
- 云端只负责 Pro 用户的数据备份、同步、多设备恢复和 staging 云测数据分发。
- iOS App 不直接连接云数据库，只通过 HTTPS API 访问后端服务。
- 删除操作默认软删除，避免云同步时丢失删除事件。
- 未获得云同步权益时，不上传用户个人数据。

## 3.1 订阅与数据边界

版本分层：

| 版本 | 本地 SQLite | 云端同步 | 卸载后恢复 | 适用场景 |
| --- | --- | --- | --- | --- |
| Free | 支持 | 不支持 | 不支持 | 单设备本地使用 |
| Pro | 支持 | 支持 | 支持 | 多设备、备份、换机恢复 |

关键规则：

- Free 不是临时内存版，仍然使用 SQLite 做本机持久化。
- Free 数据生命周期跟随 iOS App 沙盒，卸载 App 后数据清空。
- Pro 才允许写入 `change_logs` 并触发云同步任务。
- 用户从 Free 升级 Pro 后，应把当前本地 SQLite 数据作为初始基线上传云端。
- 用户从 Pro 过期回到 Free 后，本机已有数据继续可用，但暂停上传、下载和多设备同步。
- 订阅权益必须和账号或匿名云身份绑定；正式生产不可只相信本地开关。

## 4. 本地数据库方案

### 4.1 技术选型

推荐：

- `SQLite + GRDB`

当前落地：

- 已新增 `Core/Database/DatabaseClient.swift`
- 第一阶段先使用系统 `SQLite3`，避免立刻引入第三方依赖导致工程和构建复杂度上升。
- `DatabaseClient` 负责建表、旧 UserDefaults 快照迁移、读取快照、保存 Plan / Todo / Pomodoro / Profile / Settings / Entitlement。
- 保存时暂时继续写一份 UserDefaults 备份，确认 SQLite 稳定后再移除旧备份路径。
- 后续可在当前表结构上引入 `GRDB`，把手写 SQL 迁移到 Repository 层。

不优先推荐：

- `SwiftData`：最低系统要求和项目 iOS 16 目标不匹配。
- `Core Data`：可用，但调试、迁移、云端表结构映射不如 SQLite 直观。

选用 `SQLite + GRDB` 的原因：

- iOS 16 可用。
- SQL 表结构清晰，方便和云端 PostgreSQL 对齐。
- 查询能力强，适合统计页、日期分组和大量番茄记录。
- 迁移可控，适合长期迭代。

### 4.2 本地表结构

#### plans

```sql
CREATE TABLE plans (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_collapsed INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0
);
```

#### todo_items

```sql
CREATE TABLE todo_items (
  id TEXT PRIMARY KEY,
  plan_id TEXT,
  title TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  is_completed INTEGER NOT NULL DEFAULT 0,
  is_added_to_today INTEGER NOT NULL DEFAULT 1,
  task_date TEXT NOT NULL,
  cycle TEXT NOT NULL DEFAULT 'daily',
  daily_duration_minutes INTEGER NOT NULL DEFAULT 25,
  focus_timer_direction TEXT NOT NULL DEFAULT 'countDown',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);
```

#### pomodoro_sessions

```sql
CREATE TABLE pomodoro_sessions (
  id TEXT PRIMARY KEY,
  todo_id TEXT,
  plan_id TEXT,
  type TEXT NOT NULL,
  start_at TEXT NOT NULL,
  end_at TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
```

#### user_profile

```sql
CREATE TABLE user_profile (
  id TEXT PRIMARY KEY,
  nickname TEXT NOT NULL DEFAULT '',
  signature TEXT NOT NULL DEFAULT '',
  daily_goal INTEGER NOT NULL DEFAULT 4,
  updated_at TEXT NOT NULL
);
```

#### app_settings

```sql
CREATE TABLE app_settings (
  id TEXT PRIMARY KEY,
  theme_mode TEXT NOT NULL,
  language TEXT NOT NULL,
  haptics_enabled INTEGER NOT NULL DEFAULT 1,
  pomodoro_goal_per_day INTEGER NOT NULL DEFAULT 4,
  use_large_text INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
```

#### change_logs

```sql
CREATE TABLE change_logs (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL,
  synced_at TEXT
);
```

#### sync_state

```sql
CREATE TABLE sync_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

#### entitlement_state

```sql
CREATE TABLE entitlement_state (
  id TEXT PRIMARY KEY DEFAULT 'current',
  tier TEXT NOT NULL DEFAULT 'free',
  cloud_sync_enabled INTEGER NOT NULL DEFAULT 0,
  expires_at TEXT,
  updated_at TEXT NOT NULL
);
```

说明：

- 本地 `entitlement_state` 只用于 UI 和本地同步闸口。
- 生产环境最终权益必须以后端或 StoreKit 校验结果为准。
- `cloud_sync_enabled = 0` 时不得上传用户个人数据。

### 4.3 索引建议

```sql
CREATE INDEX idx_todo_items_task_date ON todo_items(task_date);
CREATE INDEX idx_todo_items_plan_id ON todo_items(plan_id);
CREATE INDEX idx_todo_items_today ON todo_items(is_added_to_today, task_date);
CREATE INDEX idx_pomodoro_sessions_end_at ON pomodoro_sessions(end_at);
CREATE INDEX idx_pomodoro_sessions_todo_id ON pomodoro_sessions(todo_id);
CREATE INDEX idx_change_logs_synced_at ON change_logs(synced_at);
```

### 4.4 删除策略

所有业务数据默认软删除：

- 删除 Todo：设置 `deleted_at`，不立即物理删除。
- 删除 Plan：设置 `deleted_at`，其下 item 可同步设置 `deleted_at` 或保留孤立数据，具体行为需产品确认后实现。
- 删除 PomodoroSession：默认不提供用户主动删除入口；如后续支持，也使用 `deleted_at`。

原因：

- 云同步必须知道删除事件。
- 多设备同步时，物理删除会导致其他设备无法正确删除同一条数据。

## 5. 本地迁移路线

### Phase A：保持现状，补齐边界

目标：

- 继续使用 `UserDefaults + Codable`。
- 明确当前模型字段和默认值。
- 所有业务写入仍通过 `AppStore`，页面不直接读写存储。

状态：

- 当前已基本满足。

### Phase B：引入 SQLite，但不改变外部行为

目标：

- 新增 `DatabaseClient`。
- 新增 Repository 层。
- 首次启动时把旧 `UserDefaults` 数据迁移进 SQLite。
- 迁移成功后保留旧数据一段时间作为回滚保护。

建议目录：

```text
Core
├── Database
│   ├── DatabaseClient.swift
│   ├── Migrations
│   └── Records
├── Repository
│   ├── TodoRepository.swift
│   ├── PlanRepository.swift
│   ├── PomodoroRepository.swift
│   └── SettingsRepository.swift
└── Storage
```

### Phase C：加入 change_logs

目标：

- 所有新增、编辑、删除、完成状态变化，都写入 `change_logs`。
- 为未来云同步做准备。
- 本阶段仍不连接云端。

### Phase D：接入云端同步

目标：

- 增加设备 ID。
- 增加登录或匿名账号策略。
- 上传本地未同步 change_logs。
- 拉取云端增量变更并合并到本地 SQLite。

### Phase C.5：端侧云测只读接入

当前先接一个低风险调试入口，不进入正式同步闭环：

- 新增 `CloudAPIClient`，默认指向 staging：`http://101.43.104.105`。
- Debug 浮层支持 `GET /health`，用于真机和模拟器连云验证。
- Debug 浮层支持 `GET /sync/pull`，只拉取 `debug-user-staging` 云测数据。
- Debug 浮层支持查看本地数据库摘要，并手动 mock `Free / Pro`；mock 结果会写入 SQLite 的 `entitlement_state`。
- 拉取的云测数据写入现有 `UserDefaults + Codable` 本地结构，并带 `debug-cloud-staging-seed` 标记。
- 重复拉取前先清理旧云测数据，不覆盖用户真实数据。
- 本阶段不实现 `POST /sync/push`，不处理冲突合并，不接正式账号体系。
- 因 staging 暂未配置 HTTPS，端侧临时允许 HTTP；正式生产必须切换 HTTPS 并收紧 ATS。

## 6. 云端方案

### 6.1 推荐部署架构

你当前已有云服务器，建议先部署 staging 环境：

```text
Caddy / Nginx
  ↓
Backend API
  ↓
PostgreSQL
```

推荐技术栈：

- Backend：`Node.js + NestJS`
- Database：`PostgreSQL`
- Deploy：优先 `Docker Compose`；国内云服务器镜像拉取受限时，使用 Ubuntu 原生部署脚本 `cloud/scripts/deploy_native_ubuntu.sh`
- Reverse Proxy：`Caddy` 或 `Nginx`

备选：

- `FastAPI + PostgreSQL`
- `Go + Gin/Fiber + PostgreSQL`
- `Swift Vapor + PostgreSQL`

### 6.2 云端表结构

云端表应和本地表保持接近，但需要增加用户、设备和版本字段。

核心表：

```text
users
devices
plans
todo_items
pomodoro_sessions
app_settings
sync_logs
```

所有业务表建议增加：

```text
user_id
device_id
server_created_at
server_updated_at
deleted_at
version
```

### 6.3 API 草案

```text
POST /auth/anonymous
POST /sync/push
GET  /sync/pull?since=cursor
POST /debug/seed
POST /debug/reset
GET  /health
```

说明：

- `POST /auth/anonymous`：第一阶段可用匿名账号或设备账号，不急着做完整注册登录。
- `POST /sync/push`：上传本地 change_logs。
- `GET /sync/pull`：根据 cursor 拉取云端变更。
- `POST /debug/seed`：生成云测数据。
- `POST /debug/reset`：重置 staging 测试数据。
- `GET /health`：云端健康检查。

## 7. 同步策略

### 7.1 Local-first

App 所有写入先落本地：

```text
User Action
  ↓
SQLite Transaction
  ↓
change_logs
  ↓
UI Refresh
  ↓
Async Sync
```

### 7.2 冲突处理

第一版冲突规则：

- 同一字段冲突：`updated_at` 晚的覆盖早的。
- 删除冲突：`deleted_at` 优先级最高。
- PomodoroSession：默认不可变记录，只追加，不覆盖。
- Settings：以最后更新时间为准。

### 7.4 订阅同步闸口

本地写入流程：

```text
User Action
  ↓
SQLite Transaction
  ↓
Check Entitlement
  ↓
Free: local only
Pro: write change_logs and schedule sync
```

伪代码：

```swift
repository.writeLocalChange()

if entitlement.cloudSyncEnabled {
    changeLogWriter.append(...)
    syncScheduler.schedule()
}
```

注意：

- Free 用户所有核心功能仍走 SQLite，不依赖网络。
- Pro 过期后不删除云端历史数据，但端侧暂停同步；恢复订阅后再继续拉取和上传。
- Debug 云测拉取不等于正式同步，不受订阅逻辑约束，但必须仅在 Debug 或 staging 环境开启。

### 7.3 同步游标

本地维护：

```text
sync_state.last_pull_cursor
sync_state.last_push_at
sync_state.device_id
```

云端返回：

```json
{
  "cursor": "server_cursor",
  "changes": []
}
```

## 8. 云测数据部署

### 8.1 环境划分

至少保留三套环境概念：

```text
local
staging
production
```

当前云服务器建议先只部署：

```text
jellytodo-staging
```

生产环境等同步闭环稳定后再开。

### 8.2 云测数据级别

沿用 App 内调试插桩级别：

| 级别 | Plan | Todo | Pomodoro Session | 用途 |
| --- | ---: | ---: | ---: | --- |
| basic | 6 | 24 | 48 | 快速看图表 |
| medium | 10 | 50 | 50 | 中等数据量 |
| large | 12 | 120 | 240 | Today / Plan 联动压测 |
| heavy | 20 | 300 | 600 | 列表和统计性能压测 |

### 8.3 Seed 脚本

云端建议提供：

```bash
pnpm seed:basic
pnpm seed:medium
pnpm seed:large
pnpm seed:heavy
pnpm seed:reset
```

Docker 部署后可执行：

```bash
docker compose exec api pnpm seed:heavy
```

### 8.4 测试数据主题

测试数据保持多元，不只围绕学习：

- 考研数学
- 考研英语
- 考研政治
- 专业课
- SwiftUI 项目
- UI 走查
- 阅读计划
- 健身恢复
- 财务复盘
- 睡眠管理
- 面试准备
- 周计划拆解

## 9. 部署建议

### 9.1 Docker Compose 草案

当前仓库已经提供第一版云测代码：

```text
cloud/
├── README.md
├── .env.example
├── docker-compose.staging.yml
└── api
    ├── Dockerfile
    ├── package.json
    └── src
```

Docker 部署入口：

```bash
cd cloud
cp .env.example .env
docker compose -f docker-compose.staging.yml up -d --build
```

Ubuntu 原生部署入口：

```bash
APP_USER=ubuntu ./cloud/scripts/deploy_native_ubuntu.sh
```

原生部署会安装 PostgreSQL、Node.js/npm、nginx，并注册 `jellytodo-cloud.service`。如果服务器本机 `curl http://127.0.0.1/health` 成功但公网访问超时，需要在云厂商安全组放行入站 TCP `80`。

```yaml
services:
  api:
    image: jellytodo-api:staging
    restart: always
    env_file:
      - .env
    ports:
      - "3000:3000"
    depends_on:
      - postgres

  postgres:
    image: postgres:16
    restart: always
    environment:
      POSTGRES_DB: jellytodo
      POSTGRES_USER: jellytodo
      POSTGRES_PASSWORD: change-me
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### 9.2 基础运维要求

- 云服务器只开放 `80/443/22`。
- PostgreSQL 不直接暴露公网端口。
- API 必须走 HTTPS。
- `.env` 不提交 GitHub。
- 每日自动备份 PostgreSQL。
- staging 和 production 数据库必须隔离。

## 10. 安全与隐私

第一版同步上线前必须满足：

- API 全部使用 HTTPS。
- 服务端不记录用户明文敏感信息。
- Token 存储在 iOS Keychain。
- App 不把本地数据库文件上传给第三方。
- Debug seed API 只允许 staging 环境开启。
- Production 禁用重置和压测接口。

## 11. 推荐下一步

优先级建议：

1. 保持当前 SQLite 第一阶段稳定，继续打磨 UI 和核心体验。
2. 把整表替换保存逐步改为 Repository 增量写入。
3. 继续扩展 `entitlement_state`，当前已支持本地 mock 区分 Free / Pro 行为。
4. 引入 `change_logs` 写入逻辑，但只在 Pro/mock Pro 下写入同步队列。
5. 在云服务器继续维护 `jellytodo-staging`。
6. 做匿名账号和单设备同步闭环。
7. 接 StoreKit 2 和服务端权益校验。
8. 再做多设备同步、冲突处理和正式账号体系。

当前不建议直接做云同步代码，因为本地数据层还没有稳定表结构。先完成本地 SQLite 迁移，会让后续上云简单很多。

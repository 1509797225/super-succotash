# JellyTodo 数据管理与云同步技术方案

## 1. 文档定位

本文档定义 `JellyTodo` 后续数据管理、本地数据库迁移、云端同步和云测数据部署方案。

治理规则：

- `ios_todo_app_technical_plan.md` 仍是项目唯一产品与技术真相源。
- 本文档是核心技术方案的数据专项附录，涉及数据模型、存储、同步、云端环境的改动必须同步更新本文档。
- 代码实现变更如果影响字段、表结构、同步协议、云测数据规则，必须先更新本文档，再改代码。

## 2. 当前状态

当前 App 使用：

- 本地存储：`UserDefaults + Codable`
- 状态入口：`AppStore`
- 数据范围：Plan、Today、TodoItem、PomodoroSession、UserProfile、AppSettings、调试插桩数据
- 云端能力：暂无
- 账号体系：暂无

当前方案适合 MVP 快速验证，但不适合长期承载复杂业务数据。

主要风险：

- `UserDefaults` 不适合存放大量任务和番茄记录。
- 不方便按日期、Plan、完成状态、专注时段做高效查询。
- 不方便做数据迁移和版本升级。
- 不方便做云同步冲突处理。
- 数据结构变化后，历史数据解析失败风险会增大。

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
- 云端只负责备份、同步、多设备恢复和云测数据分发。
- iOS App 不直接连接云数据库，只通过 HTTPS API 访问后端服务。
- 删除操作默认软删除，避免云同步时丢失删除事件。

## 4. 本地数据库方案

### 4.1 技术选型

推荐：

- `SQLite + GRDB`

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
- Deploy：`Docker Compose`
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

部署入口：

```bash
cd cloud
cp .env.example .env
docker compose -f docker-compose.staging.yml up -d --build
```

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

1. 保持现有 `UserDefaults` 版本稳定，继续打磨 UI 和核心体验。
2. 新建 SQLite/GRDB 技术分支，只做本地数据库迁移，不接云。
3. 本地迁移完成后，引入 `change_logs`。
4. 在云服务器部署 `jellytodo-staging`。
5. 做匿名账号和单设备同步闭环。
6. 再做多设备同步、冲突处理和正式账号体系。

当前不建议直接做云同步代码，因为本地数据层还没有稳定表结构。先完成本地 SQLite 迁移，会让后续上云简单很多。

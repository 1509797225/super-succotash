# JellyTodo 数据管理与云同步技术方案

## 1. 文档定位

本文档定义 `JellyTodo` 后续数据管理、本地数据库迁移、云端同步和云测数据部署方案。

治理规则：

- `ios_todo_app_technical_plan.md` 仍是项目唯一产品与技术真相源。
- 本文档是核心技术方案的数据专项附录，涉及数据模型、存储、同步、云端环境的改动必须同步更新本文档。
- 代码实现变更如果影响字段、表结构、同步协议、云测数据规则，必须先更新本文档，再改代码。

## 2. 当前状态

当前 App 使用：

- 本地存储：SQLite 第一阶段 + `UserDefaults + Codable` 回滚备份 + 本地恢复点
- 状态入口：`AppStore`
- 数据范围：Plan、Today、TodoItem、PomodoroSession、UserProfile、AppSettings、调试插桩数据
- 云端能力：staging API 已部署，端侧 Debug 入口支持健康检查、只读拉取云测数据，Set 页支持 Pro/mock Pro 手动同步、云端备份点创建、云端恢复点列表和显式恢复
- 账号体系：暂无
- 订阅体系：端侧已接入 StoreKit 2 骨架，服务端已建立 `cloud_entitlements` 权益闸口和 staging 交易同步接口；staging 匿名身份当前自动授予 Pro 同步资格，便于联调

当前方案已经从纯 `UserDefaults` 进入 SQLite 迁移第一阶段，并完成 `change_logs`、本地恢复点、云端备份点、Set 页 `Backup & Sync` 入口、StoreKit 2 端侧骨架、StoreKit staging 交易同步、匿名云身份、服务端权益闸口、staging 手动 push、基础 pull merge 和安全版前台自动同步。正式生产级同步仍未完成，因为还缺 App Store Server API 级交易验签、多设备冲突策略和云端恢复后的“设为新基线”策略。

主要风险：

- 第一阶段 SQLite 仍采用整表替换保存，尚未充分利用增量 SQL 写入。
- 尚未建立 Repository 层，页面状态和持久化边界还可以继续拆清楚。
- `change_logs` 已写入并可手动 push，手动同步后会按 cursor 拉取云端增量。
- 当前 pull merge 是基础版 last-write-wins，冲突处理、云端恢复后的新基线上传策略和 App Store Server API 级交易验签仍未完成。
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
- 正式同步必须可解释、可手动触发、可回退；任何自动拉取都不得静默覆盖用户真实本地数据。

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
- Pro 用户必须能在 Set 页看到同步状态、手动触发同步、查看同步历史，并在必要时回到本地恢复点。

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

#### sync_history

```sql
CREATE TABLE sync_history (
  id TEXT PRIMARY KEY,
  direction TEXT NOT NULL,
  status TEXT NOT NULL,
  changed_count INTEGER NOT NULL DEFAULT 0,
  message TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);
```

说明：

- `direction` 固定为 `push / pull / full / restore`。
- `status` 固定为 `success / failed / skipped`。
- 用于 Set 页展示最近同步记录，帮助用户知道数据什么时候上传、什么时候拉取、是否失败。

#### local_backup_snapshots

```sql
CREATE TABLE local_backup_snapshots (
  id TEXT PRIMARY KEY,
  reason TEXT NOT NULL,
  snapshot_path TEXT NOT NULL,
  plans_count INTEGER NOT NULL DEFAULT 0,
  todos_count INTEGER NOT NULL DEFAULT 0,
  sessions_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
```

说明：

- 每次手动同步、恢复前、重要自动 merge 前，先创建本地恢复点。
- `snapshot_path` 指向 App 沙盒内的 JSON 快照文件，不建议把完整快照直接塞进主表。
- Free 用户也可使用本地恢复点，但卸载 App 后随沙盒删除。
- Pro 用户可把当前本地快照同步到云端，形成云端备份点。

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
CREATE INDEX idx_sync_history_created_at ON sync_history(created_at);
CREATE INDEX idx_backup_snapshots_created_at ON local_backup_snapshots(created_at);
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
- 已在 Pro/mock Pro 下写入本地同步队列；Free 只保留本地数据，不写上传队列。

### Phase D：接入云端同步

目标：

- 增加设备 ID。
- 增加登录或匿名账号策略。
- 上传本地未同步 change_logs。
- 拉取云端增量变更并合并到本地 SQLite。
- Set 页新增 `Backup & Sync` 模块，先支持手动同步、同步状态、同步历史和本地恢复点。
- 自动同步必须在手动同步稳定后再开启，且必须先创建可回退恢复点。

当前状态：

- 已完成 staging `POST /sync/push`。
- 已完成端侧 `Sync Now` 手动上传未同步 `change_logs`。
- 已完成上传成功后标记本地变更为 synced。
- 已完成端侧基础 `GET /sync/pull?since=cursor` 合并，支持 Plan、Todo、PomodoroSession、AppSettings 增量回流。
- 已完成端侧匿名云身份创建和本地持久化；首次 Pro/mock Pro 手动同步时会调用 `POST /auth/anonymous`，后续复用同一 userID/deviceID。
- 已完成服务端 `cloud_entitlements` 权益表和 `push/pull` 闸口；当前 staging 通过 `STAGING_AUTO_GRANT_PRO` 自动给匿名用户 Pro 同步资格。
- 已完成 StoreKit 2 端侧骨架：订阅商品 ID、商品加载、当前订阅检测、购买入口和 Set 页订阅状态展示。
- 已完成 staging `POST /entitlements/storekit/sync`，端侧检测到 StoreKit verified transaction 后可把交易摘要同步到服务端并更新 `cloud_entitlements`。
- 已完成安全版前台自动同步：App 回到前台、Pro 可用、超过 15 分钟冷却且无同步并发时，自动执行一次增量 push + pull；失败只写同步记录，不打断本地使用。
- 已完成同步历史、本地恢复点和恢复前保护备份。
- 已完成云端备份点一期：服务端 `backup_snapshots` 表、`POST /backup/snapshots`、`GET /backup/snapshots`、`POST /backup/restore`，端侧 Set 页可创建云端恢复点、查看云端恢复点并显式恢复。
- 未完成正式账号登录、App Store Server API 级交易验签、多设备冲突处理和云端恢复后的新基线上传策略。

### Phase C.5：端侧云测与手动同步接入

当前先接一个低风险调试、手动同步和前台自动同步入口，不进入复杂后台同步闭环：

- 新增 `CloudAPIClient`，默认指向 staging：`http://101.43.104.105`。
- Debug 浮层支持 `GET /health`，用于真机和模拟器连云验证。
- Debug 浮层支持 `GET /sync/pull`，只拉取 `debug-user-staging` 云测数据。
- Set 页 `Backup & Sync` 支持手动 `Sync Now`，上传 Pro/mock Pro 下积累的本地 `change_logs`。
- 服务端 `POST /sync/push` 已支持 Plan、Todo、PomodoroSession、AppSettings 的 staging merge，并写入 `sync_logs`。
- Debug 浮层支持查看本地数据库摘要，并手动 mock `Free / Pro`；mock 结果会写入 SQLite 的 `entitlement_state`。
- 拉取的云测数据写入现有 `UserDefaults + Codable` 本地结构，并带 `debug-cloud-staging-seed` 标记。
- 重复拉取前先清理旧云测数据，不覆盖用户真实数据。
- 本阶段不处理正式冲突合并，不接正式账号体系，不开启复杂后台同步。
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
backup_snapshots
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

#### backup_snapshots

```sql
CREATE TABLE backup_snapshots (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
  reason TEXT NOT NULL DEFAULT '',
  snapshot JSONB NOT NULL,
  plans_count INTEGER NOT NULL DEFAULT 0,
  todos_count INTEGER NOT NULL DEFAULT 0,
  sessions_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

说明：

- `snapshot` 复用端侧 `StorageSnapshot` JSON 格式。
- 列表接口只返回 metadata，不返回完整快照，避免 Set 页打开时传输过大。
- 恢复接口只取回快照，由端侧先创建本地保护性恢复点，再应用到本地 SQLite。

### 6.3 API 草案

```text
POST /auth/anonymous
POST /sync/push
GET  /sync/pull?since=cursor
POST /backup/snapshots
GET  /backup/snapshots
POST /backup/restore
POST /debug/seed
POST /debug/reset
GET  /health
```

说明：

- `POST /auth/anonymous`：第一阶段已用于创建端侧匿名云身份，并持久化到本地 SQLite `meta`。
- `POST /sync/push`：上传本地 change_logs；staging 已落地，当前用于手动 push。
- `GET /sync/pull`：根据 cursor 拉取云端变更。
- `POST /backup/snapshots`：Pro 用户创建云端备份点；staging 已落地。
- `GET /backup/snapshots`：Pro 用户查看自己的云端备份点列表；staging 已落地。
- `POST /backup/restore`：Pro 用户显式选择某个云端备份点并取回快照，端侧负责应用恢复；staging 已落地。
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
- 正式拉取远端数据前必须先创建本地恢复点；如果合并结果异常，用户可手动回退。
- 自动同步不得直接把远端完整快照覆盖本地库，只能按增量变更合并。

### 7.3 备份与云数据管理

Set 页必须新增独立模块：

```text
Backup & Sync
```

模块职责：

- 展示当前数据模式：`Free Local Only` / `Pro Cloud Sync` / `Debug Pro Mock`。
- 展示云同步状态：是否开启、上次同步时间、待上传数量、最近失败原因。
- 提供 `Sync Now` 手动同步入口。
- 提供 `Create Local Backup` 手动创建本地恢复点。
- 提供 `Backup Points` 恢复点列表，支持按时间点回退。
- 提供 `Sync History` 同步历史，展示最近 push / pull / restore 记录。
- Pro 用户展示云端备份状态；Free 用户展示升级提示，但不得上传个人数据。

第一版 UI 建议：

```text
Set
└── Backup & Sync
    ├── Cloud Sync       Pro / Off / Debug
    ├── Sync Now         手动同步
    ├── Last Sync        2026-04-19 20:30
    ├── Pending Uploads  12
    ├── Backup Points    5
    └── Sync History     最近 20 条
```

手动同步流程：

```text
User taps Sync Now
  ↓
Create local_backup_snapshot(reason: manual_sync_before_merge)
  ↓
Push unsynced change_logs
  ↓
Pull remote changes since last_pull_cursor
  ↓
Merge into SQLite transaction
  ↓
Write sync_history(success / failed)
  ↓
Update sync_state
```

自动同步触发条件：

- App 进入前台时，如果 Pro 且距离上次同步超过固定冷却时间，可尝试同步。
- App 进入后台前，如果存在未上传 change_logs，可尝试快速上传。
- 网络恢复时，如果存在未上传 change_logs，可排队同步。
- 用户完成关键操作后只写 change_logs，不立即每次都打网络请求，避免频繁请求和耗电。

自动同步安全限制：

- 自动同步只允许处理增量，不允许远端整库覆盖本地。
- 自动 pull 合并前必须创建本地恢复点，或至少在本次事务中保留可回滚快照。
- 如果本地有未同步变更且远端同实体也有变更，必须走冲突规则，不得静默丢弃本地变更。
- 自动同步失败不能影响本地使用，失败原因写入 `sync_history`。
- Free 或 Pro 过期状态下不得上传用户个人数据。

恢复点规则：

- 本地恢复点保存 App 沙盒内的 JSON 快照或 SQLite 导出快照。
- 手动同步前、手动恢复前、云端大批量拉取前必须创建恢复点。
- 默认保留最近 10 个本地恢复点，超过数量可清理最旧记录。
- 用户手动创建的恢复点默认不自动清理，除非用户主动删除。
- 恢复操作本身也要写入 `sync_history(direction: restore)`。

云端备份点规则：

- 仅 Pro 用户可使用云端备份点。
- 云端备份点按 `user_id` 隔离，设备只作为来源标记。
- 恢复云端备份前必须先创建本地恢复点。
- 云端恢复是用户显式操作，不允许 App 自动选择历史节点覆盖当前数据。
- 当前一期云端恢复会把所选快照应用到本地，并保存新的本地快照；后续需要补充“恢复后是否上传为云端新基线”的显式策略，避免多设备同步把旧云端数据重新覆盖回来。

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

### 7.5 同步游标

本地维护：

```text
sync_state.last_pull_cursor
sync_state.last_push_at
sync_state.device_id
sync_state.last_backup_at
sync_state.pending_upload_count
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
4. 继续维护 `jellytodo-staging`，当前已支持健康检查、云测拉取和手动 push。
5. 强化云端 pull merge，把当前基础 last-write-wins 升级为可解释的冲突策略。
6. 明确“云端恢复后是否设为新基线”的用户操作和上传策略。
7. 在 App Store Connect 创建订阅商品，当前端侧占位 Product ID 为 `jellytodo.pro.monthly`。
8. 把当前 staging client-verified 交易同步升级为 App Store Server API / JWS 级验签，再写入 `cloud_entitlements`。
9. 关闭 staging 自动授权，确保生产环境只有服务端确认 Pro 后才能同步个人数据。
10. 在前台自动同步稳定后，再考虑网络恢复和低频后台触发。
11. 再做多设备同步、冲突处理和正式账号体系。

当前不建议直接开启复杂后台同步。先把手动同步和前台自动同步在真机上跑稳定，再考虑网络恢复和低频后台触发，会更安全。

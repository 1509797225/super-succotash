# JellyTodo 账号接入技术方案

## 1. 文档定位

本文档定义 `JellyTodo` 账号体系、登录接入、匿名身份迁移、订阅权益绑定和云同步鉴权方案。

治理规则：

- `ios_todo_app_technical_plan.md` 仍是项目唯一产品与技术真相源。
- `data_management_and_cloud_sync_plan.md` 定义数据、同步、云端备份和云测环境。
- 本文档是账号与认证专项附录；凡涉及登录方式、用户表、token、账号迁移、订阅绑定、同步鉴权的变更，必须同步更新本文档。
- 账号接入必须优先保护现有本地数据，不能因为登录、退出或迁移导致本地任务丢失。

## 2. 结论

一期不接入重型开源账号系统，也不从 0 做密码体系。

推荐路线：

```text
Sign in with Apple
  ↓
JellyTodo Backend 验证 Apple identity token
  ↓
PostgreSQL users / auth_sessions
  ↓
JellyTodo accessToken + refreshToken
  ↓
iOS Keychain 本地保存登录态
```

核心判断：

- iOS 产品优先使用 `Sign in with Apple`，体验和合规成本最低。
- 不做密码登录一期，避免邮箱验证、找回密码、防撞库和风控成本。
- 用户业务数据、订阅权益、云同步归属仍然由 JellyTodo 后端和 PostgreSQL 管理。
- 后续可扩展邮箱、手机号、Google 等登录方式，但不能影响现有 `uid`。

## 3. 当前状态

当前已具备：

- 服务端 `users` 表，但目前主要用于匿名云身份。
- `POST /auth/anonymous`：创建匿名 `userID/deviceID`。
- iOS 端 `CloudIdentity`：本地保存 `userID/deviceID/createdAt`。
- 云同步和云备份接口当前通过请求体里的 `userID/deviceID` 识别用户。
- StoreKit 2 端侧骨架与 staging 交易同步接口。
- `cloud_entitlements` 权益表，staging 当前可自动授予匿名用户 Pro，便于联调。

当前不足：

- 没有正式账号登录。
- 没有 access token / refresh token。
- 同步接口还未从 token 中解析用户身份。
- 匿名身份和正式账号没有绑定/迁移流程。
- 订阅权益还没有生产级 App Store Server API 验签。
- 退出登录、删除账号、换机恢复、合规删除还未实现。

## 4. 目标

账号体系一期目标：

- 支持 Apple 登录。
- 每个正式用户拥有稳定 `uid`。
- 支持匿名用户升级为正式账号，现有本地数据不丢失。
- 支持把匿名云数据迁移到正式账号。
- 支持 Pro 订阅权益绑定到正式账号。
- 后续云同步接口通过 token 识别用户，不再信任端侧传入的 `userID`。
- Set 页展示账号状态、登录入口、退出登录入口和数据同步身份状态。

非目标：

- 一期不做密码注册/登录。
- 一期不做手机号验证码登录。
- 一期不做第三方 OAuth 聚合平台。
- 一期不部署 Keycloak、Ory、Supabase Auth 等重型认证系统。
- 一期不做企业级多组织、多租户、管理员后台。

## 5. 方案对比

| 方案 | 优点 | 风险 | 结论 |
| --- | --- | --- | --- |
| 自己全写密码账号 | 完全可控 | 密码安全、找回密码、防爆破、邮箱验证成本高 | 不推荐一期 |
| Keycloak | 开源、能力完整 | 太重，部署和配置复杂 | 暂不接 |
| Ory Kratos/Hydra | 专业、开源 | 学习和运维成本高 | 暂不接 |
| Supabase Auth | 快速、省事 | 多平台依赖，和现有自建后端边界变复杂 | 可作为后备 |
| Firebase Auth | 快速、省事 | 非自托管，国内网络和掌控感一般 | 暂不接 |
| Apple 登录 + 自建轻量认证层 | 最贴合 iOS，复杂度适中，数据仍自有 | 需要自己写 token/session 和 Apple token 验证 | 推荐 |

## 6. 架构

```text
iOS App
  ↓ Sign in with Apple
Apple ID Provider
  ↓ identityToken / authorizationCode
iOS App
  ↓ POST /auth/apple
JellyTodo Backend
  ↓ verify Apple token
PostgreSQL
  ↓ users / auth_identities / auth_sessions
JellyTodo Backend
  ↓ accessToken / refreshToken
iOS App Keychain
```

登录后云同步链路：

```text
iOS App
  ↓ Bearer accessToken
Backend Auth Middleware
  ↓ req.user.id
Sync / Backup / Entitlement API
  ↓
PostgreSQL user_id = req.user.id
```

## 7. 数据模型

### 7.1 users

正式用户主表。

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT,
  nickname TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
```

说明：

- `id` 是 JellyTodo 自己生成的稳定 `uid`，不要直接使用 Apple `sub`。
- `email` 可能为空，因为 Apple 允许隐藏邮箱且后续登录不一定每次返回 email。
- `deleted_at` 用于账号注销后的软删除和数据清理流程。

### 7.2 auth_identities

第三方身份绑定表。

```sql
CREATE TABLE auth_identities (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL,
  provider_subject TEXT NOT NULL,
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(provider, provider_subject)
);
```

一期：

- `provider = 'apple'`
- `provider_subject = Apple identity token 里的 sub`

后续扩展：

- `provider = 'email'`
- `provider = 'phone'`
- `provider = 'google'`

### 7.3 auth_sessions

登录会话和 refresh token 管理。

```sql
CREATE TABLE auth_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT,
  refresh_token_hash TEXT NOT NULL,
  user_agent TEXT,
  ip_address TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

规则：

- 服务端只保存 refresh token hash，不保存明文 token。
- access token 短有效期，建议 15 分钟到 1 小时。
- refresh token 长有效期，建议 30 到 90 天。
- 退出登录时 revoke 当前 session。
- 修改密码功能未做前，不需要全设备下线；后续可以补。

### 7.4 devices

现有设备表继续保留。

需要补充：

```sql
ALTER TABLE devices ADD COLUMN auth_user_id TEXT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE devices ADD COLUMN anonymous_user_id TEXT;
```

说明：

- `auth_user_id` 表示当前设备登录的正式账号。
- `anonymous_user_id` 保留原匿名身份，用于迁移和问题排查。

### 7.5 cloud_entitlements

权益表继续以 `user_id` 为主键。

生产规则：

- 正式登录后，`cloud_entitlements.user_id` 应指向正式 `uid`。
- 匿名 userID 在 staging 可继续使用，但生产不应自动授予 Pro。
- StoreKit 验签成功后，把 Pro 权益写入正式 `uid`。

## 8. API 设计

### 8.1 POST /auth/apple

用途：

- 使用 Apple 登录创建或登录 JellyTodo 账号。

请求：

```json
{
  "identityToken": "apple.jwt",
  "authorizationCode": "optional",
  "deviceID": "device-id",
  "anonymousUserID": "optional-existing-anonymous-user-id",
  "displayName": "optional",
  "email": "optional"
}
```

响应：

```json
{
  "user": {
    "id": "uid",
    "email": "user@example.com",
    "nickname": "Zhang"
  },
  "accessToken": "jwt",
  "refreshToken": "opaque-token",
  "expiresAt": "2026-04-20T12:00:00.000Z",
  "migration": {
    "anonymousUserID": "old-id",
    "migrated": true,
    "plans": 12,
    "todos": 80,
    "sessions": 240
  }
}
```

服务端行为：

- 验证 Apple identity token 的签名、issuer、audience、expiration。
- 读取 Apple `sub`。
- 如果 `auth_identities(provider='apple', provider_subject=sub)` 已存在，登录现有用户。
- 如果不存在，创建 `users` 和 `auth_identities`。
- 如果传入 `anonymousUserID`，且该匿名数据尚未绑定其他正式账号，则执行匿名数据迁移。
- 创建 `auth_sessions`，返回 access token 和 refresh token。

### 8.2 POST /auth/refresh

用途：

- access token 过期后刷新。

请求：

```json
{
  "refreshToken": "opaque-token",
  "deviceID": "device-id"
}
```

响应：

```json
{
  "accessToken": "jwt",
  "refreshToken": "new-opaque-token",
  "expiresAt": "2026-04-20T12:00:00.000Z"
}
```

规则：

- refresh token 建议轮换。
- 旧 refresh token 使用后立即失效。
- 检测到已撤销 token 被再次使用时，可以撤销该用户所有 sessions。

### 8.3 POST /auth/logout

用途：

- 退出当前设备登录。

请求：

```json
{
  "refreshToken": "opaque-token",
  "deviceID": "device-id"
}
```

行为：

- revoke 当前 session。
- iOS 清理 Keychain 登录态。
- 本地数据默认保留，不自动删除。

### 8.4 GET /me

用途：

- 获取当前登录用户和权益状态。

响应：

```json
{
  "user": {
    "id": "uid",
    "email": "user@example.com",
    "nickname": "Zhang"
  },
  "entitlement": {
    "tier": "pro",
    "cloudSyncEnabled": true,
    "expiresAt": null
  }
}
```

### 8.5 DELETE /me

用途：

- 账号注销。

一期可以只做服务端能力，不一定先开放 UI。

规则：

- 必须二次确认。
- 注销后 revoke sessions。
- 云端业务数据进入删除队列或软删除状态。
- 本地端应提示用户是否保留本机数据。

## 9. 同步接口鉴权改造

当前同步接口：

```text
POST /sync/push       body.userID
GET  /sync/pull       query.userID
POST /backup/snapshots body.userID
GET  /backup/snapshots query.userID
POST /backup/restore  body.userID
```

目标改造：

```text
Authorization: Bearer accessToken
```

服务端从 token 中解析：

```text
req.user.id
req.session.id
req.device.id
```

迁移期兼容策略：

- staging 保留 `userID` 参数，方便调试。
- 生产优先使用 token，忽略端侧传入的 `userID`。
- 如果 token 和 body/query 里的 `userID` 不一致，生产环境直接拒绝。
- Debug seed API 继续通过 `DEBUG_SECRET` 保护，不走普通用户 token。

## 10. 匿名数据迁移

### 10.1 场景

用户使用 Free 或 mock Pro 一段时间后，点击 Apple 登录。

端侧已有：

- 本地 SQLite 数据。
- `CloudIdentity.userID` 匿名云身份。
- 可能已有匿名云端数据和恢复点。

登录后需要：

- 保留本地数据。
- 把匿名云端数据迁移到正式 `uid`。
- 把订阅权益绑定到正式 `uid`。
- 后续同步使用正式账号。

### 10.2 迁移策略

推荐一期使用“认领匿名云身份”：

```text
anonymous user_id
  ↓ login with Apple
official uid
  ↓ server transaction
update plans / todos / sessions / backups / entitlements user_id
```

迁移表范围：

- `devices`
- `plans`
- `todo_items`
- `pomodoro_sessions`
- `app_settings`
- `sync_logs`
- `backup_snapshots`
- `cloud_entitlements`

迁移事务规则：

- 必须在一个数据库事务中完成。
- 如果匿名 userID 已被其他正式账号认领，拒绝迁移。
- 迁移完成后记录 `account_migrations`。

### 10.3 account_migrations

```sql
CREATE TABLE account_migrations (
  id TEXT PRIMARY KEY,
  anonymous_user_id TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT,
  plans_count INTEGER NOT NULL DEFAULT 0,
  todos_count INTEGER NOT NULL DEFAULT 0,
  sessions_count INTEGER NOT NULL DEFAULT 0,
  backups_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(anonymous_user_id)
);
```

端侧迁移后：

- 保存正式账号 token。
- 保存正式 `AccountState`。
- 保留旧 `CloudIdentity` 只用于调试展示或迁移记录。
- 立即执行一次手动同步，确认本地和正式云端一致。

## 11. 端侧设计

### 11.1 新增模型

```swift
struct AccountState: Codable, Equatable
struct AuthSession: Codable, Equatable
struct AccountUser: Codable, Equatable
enum AuthProvider: String, Codable
enum AccountStatus: String, Codable
```

建议字段：

```swift
struct AccountUser {
    let id: String
    var email: String?
    var nickname: String
}

struct AuthSession {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct AccountState {
    var user: AccountUser?
    var session: AuthSession?
    var provider: AuthProvider?
    var status: AccountStatus
}
```

### 11.2 存储

本地存储规则：

- `accessToken` 和 `refreshToken` 必须存 Keychain。
- `AccountUser` 可存 SQLite meta 或 UserDefaults 备份。
- 不把 token 放入普通 UserDefaults。
- 退出登录时清理 Keychain token，但默认保留本地业务数据。

### 11.3 AppStore 行为

新增接口：

```swift
func signInWithApple()
func refreshAuthSessionIfNeeded() async
func logout() async
func loadAccountState()
func refreshMe() async
```

同步行为变化：

- `performManualSync()` 先确保 token 可用。
- Pro 云同步优先需要正式账号 token。
- staging 可兼容匿名身份。
- access token 过期时自动 refresh 一次，失败则提示重新登录。

### 11.4 Set 页 UI

新增账号模块：

```text
Account
  登录状态
  Sign in with Apple
  当前 UID
  邮箱
  Logout
```

交互规则：

- 未登录：展示 Apple 登录按钮和“登录后可跨设备恢复 Pro 数据”说明。
- 已登录：展示昵称、邮箱、UID 短码、订阅状态、退出登录。
- 退出登录：本地数据默认保留，只停止云同步；用户可继续本机使用。
- 删除账号：后置，不在一期 UI 暴露。

## 12. StoreKit 与账号绑定

生产规则：

- 端侧 StoreKit 只负责发起购买和读取本地 transaction。
- 服务端必须通过 App Store Server API 或 JWS 验签确认交易。
- 验签通过后，把 Pro 权益写入当前正式 `uid`。
- 未登录购买时，端侧需要提示“登录后开启云同步/备份”；可先保留本地 Pro 状态，但云同步必须等账号绑定。

推荐流程：

```text
User signs in
  ↓
iOS reads current StoreKit entitlements
  ↓
POST /entitlements/storekit/sync with accessToken
  ↓
Server verifies transaction
  ↓
cloud_entitlements.user_id = uid
```

特殊场景：

- 用户换设备：登录账号后，服务端权益决定是否可云同步。
- 用户退出登录：本地 Pro UI 可按 StoreKit 显示，但云同步暂停。
- 家庭共享、退款、过期：以服务端定期验签或 App Store Server Notification 为准。

## 13. 安全要求

Apple token 验证：

- 校验 `iss = https://appleid.apple.com`。
- 校验 `aud = App Bundle ID / Service ID`。
- 校验签名，使用 Apple JWKS。
- 校验 `exp` 未过期。
- 使用 `sub` 作为 Apple 身份唯一标识。

Token 安全：

- access token 短期有效。
- refresh token 使用随机不可预测字符串。
- refresh token 服务端只存 hash。
- iOS token 只存 Keychain。
- 生产环境 API 必须 HTTPS。

接口安全：

- 同步和备份接口生产环境必须鉴权。
- 生产环境不能信任 body/query 传入的 `userID`。
- Debug API 必须只在 staging 开启，并使用 `DEBUG_SECRET`。
- 账号注销、恢复云备份、覆盖云端基线等危险操作必须二次确认。

## 14. 分阶段实施计划

### Phase A：文档与服务端表结构

- 新增本文档。
- 服务端新增 `auth_identities`、`auth_sessions`、`account_migrations`。
- `users` 表补齐 `avatar_url/status/deleted_at` 等字段。
- 增加索引和唯一约束。

### Phase B：Apple 登录服务端

- 实现 Apple JWKS 拉取和缓存。
- 实现 `POST /auth/apple`。
- 实现 session 创建、refresh token hash、access token 签发。
- 实现 `POST /auth/refresh`、`POST /auth/logout`、`GET /me`。

### Phase C：端侧账号状态

- 新增 `AccountState`、`AuthSession`、`AccountClient`、`KeychainClient`。
- Set 页新增账号模块。
- 接入 `AuthenticationServices` 的 Apple 登录按钮。
- 登录成功后保存 token 到 Keychain。

### Phase D：匿名迁移

- `POST /auth/apple` 支持 `anonymousUserID`。
- 服务端迁移匿名云数据到正式 `uid`。
- 端侧登录成功后触发一次安全同步。
- Set 页展示迁移结果或失败原因。

### Phase E：同步接口 token 化

- 服务端同步、备份、权益接口支持 Bearer token。
- iOS `CloudAPIClient` 自动附带 access token。
- token 过期自动 refresh。
- staging 保留匿名兼容，生产逐步禁用 body/query userID。

### Phase F：订阅生产化

- App Store Connect 创建商品。
- 服务端接 App Store Server API / JWS 验签。
- `cloud_entitlements` 绑定正式 `uid`。
- 关闭 `STAGING_AUTO_GRANT_PRO` 在生产环境的等效逻辑。

## 15. 测试计划

基础登录：

- 首次 Apple 登录创建新用户。
- 同一个 Apple ID 再次登录命中同一用户。
- access token 过期后 refresh 成功。
- refresh token 失效后要求重新登录。
- logout 后当前 session 失效。

匿名迁移：

- 匿名用户有本地数据但无云数据，登录后本地数据不丢。
- 匿名用户已有云端 Plan/Todo/Session/Backup，登录后迁移到正式 `uid`。
- 同一个匿名 userID 不能被两个正式账号认领。
- 迁移失败不影响本地数据。

同步鉴权：

- 未登录或 token 无效时，生产同步接口拒绝。
- Free 登录用户不能上传云数据。
- Pro 登录用户可以手动同步、自动同步、创建云备份、恢复云备份。
- body 伪造其他 `userID` 不应越权访问数据。

订阅：

- 登录后 StoreKit active 交易同步到服务端。
- 过期交易不能开启云同步。
- 退出登录后云同步暂停。
- 换机登录后权益可恢复。

UI：

- Set 页未登录状态清晰。
- Set 页已登录状态显示 UID、邮箱和订阅状态。
- 中英文切换后账号模块不乱版。
- 小屏设备上 Apple 登录按钮和账号信息不挤压。

## 16. 当前暂不做

- 密码注册/登录。
- 手机号短信登录。
- 邮箱验证码登录。
- 多 OAuth provider 聚合。
- 管理后台。
- 账号好友/社交关系。
- 团队空间或多人协作。
- 企业级 SSO。

## 17. 推荐下一步

建议下一步先做服务端账号基础：

1. 补 `users`、`auth_identities`、`auth_sessions`、`account_migrations` 表结构。
2. 实现 Apple token 验证工具。
3. 实现 `POST /auth/apple`、`POST /auth/refresh`、`POST /auth/logout`、`GET /me`。
4. 再做端侧 `AccountClient + KeychainClient + Set 页账号模块`。
5. 最后把同步接口从 `userID` 参数逐步迁移到 Bearer token。

这条路径最稳：先有账号身份，再做数据归属，再做同步鉴权，避免账号还没稳定就大改同步逻辑。

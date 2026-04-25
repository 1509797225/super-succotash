import "dotenv/config";
import express from "express";
import cors from "cors";
import { createHash, createHmac, createPublicKey, randomBytes, randomUUID, verify } from "node:crypto";
import { initSchema, pool, withTransaction } from "./db.js";
import { debugSummary, resetDebugData, seedDebugData } from "./seed.js";

const app = express();
const port = Number(process.env.PORT ?? 3000);

app.use(cors());
app.use(express.json({ limit: "8mb" }));

const asyncHandler = (handler) => (request, response, next) => {
  Promise.resolve(handler(request, response, next)).catch(next);
};

function requireDebugSecret(request, response, next) {
  const expected = process.env.DEBUG_SECRET;
  if (!expected) {
    response.status(500).json({ error: "DEBUG_SECRET is not configured" });
    return;
  }

  if (request.header("x-debug-secret") !== expected) {
    response.status(401).json({ error: "Invalid debug secret" });
    return;
  }

  next();
}

app.get("/health", async (_request, response) => {
  const db = await pool.query("SELECT now() AS now");
  response.json({
    ok: true,
    service: "jellytodo-cloud-api",
    environment: process.env.NODE_ENV ?? "development",
    databaseTime: db.rows[0].now,
  });
});

app.post("/auth/anonymous", async (_request, response) => {
  const now = new Date().toISOString();
  const userID = randomUUID();
  const deviceID = randomUUID();

  await withTransaction(async (client) => {
    await client.query(
      "INSERT INTO users (id, nickname, created_at, updated_at) VALUES ($1, $2, $3, $3)",
      [userID, "Anonymous", now]
    );
    await client.query(
      "INSERT INTO devices (id, user_id, device_name, platform, last_seen_at) VALUES ($1, $2, $3, $4, $5)",
      [deviceID, userID, "iPhone", "ios", now]
    );
    await ensureDefaultEntitlement(client, userID);
  });

  response.status(201).json({ userID, deviceID });
});

app.post("/auth/apple", asyncHandler(async (request, response) => {
  const identityToken = typeof request.body?.identityToken === "string" ? request.body.identityToken : "";
  const authorizationCode = typeof request.body?.authorizationCode === "string" ? request.body.authorizationCode : "";
  const deviceID = typeof request.body?.deviceID === "string" && request.body.deviceID
    ? request.body.deviceID
    : randomUUID();
  const anonymousUserID = typeof request.body?.anonymousUserID === "string" ? request.body.anonymousUserID : "";
  const displayName = typeof request.body?.displayName === "string" ? request.body.displayName.trim().slice(0, 80) : "";
  const requestEmail = typeof request.body?.email === "string" ? request.body.email.trim().slice(0, 160) : "";

  if (!identityToken) {
    response.status(400).json({ error: "identityToken is required" });
    return;
  }

  const applePayload = await verifyAppleIdentityToken(identityToken);
  const appleSubject = applePayload.sub;
  const email = requestEmail || applePayload.email || null;
  const nickname = displayName || (email ? email.split("@")[0] : "Jelly User");

  const result = await withTransaction(async (client) => {
    let userID;
    const identityResult = await client.query(
      "SELECT user_id FROM auth_identities WHERE provider = 'apple' AND provider_subject = $1 LIMIT 1",
      [appleSubject]
    );

    if (identityResult.rows[0]) {
      userID = identityResult.rows[0].user_id;
      await client.query(
        "UPDATE users SET email = COALESCE(email, $2), nickname = CASE WHEN nickname = '' THEN $3 ELSE nickname END, updated_at = now() WHERE id = $1",
        [userID, email, nickname]
      );
    } else {
      userID = randomUUID();
      await client.query(
        `
        INSERT INTO users (id, email, nickname, created_at, updated_at)
        VALUES ($1, $2, $3, now(), now())
        `,
        [userID, email, nickname]
      );
      await client.query(
        `
        INSERT INTO auth_identities (id, user_id, provider, provider_subject, email, created_at, updated_at)
        VALUES ($1, $2, 'apple', $3, $4, now(), now())
        `,
        [randomUUID(), userID, appleSubject, email]
      );
    }

    const migration = await migrateAnonymousUserData(client, anonymousUserID, userID, deviceID);
    await ensureSignedInDevice(client, userID, deviceID, anonymousUserID);
    await ensureDefaultEntitlement(client, userID);

    const session = await createAuthSession(client, userID, deviceID, request);
    const entitlement = await loadCloudEntitlementWith(client, userID);
    const user = await loadAuthUser(client, userID);

    await client.query(
      `
      INSERT INTO sync_logs (
        id, user_id, device_id, entity_type, entity_id, operation, payload, created_at, synced_at
      )
      VALUES ($1, $2, $3, 'auth_session', $4, 'apple_login', $5, now(), now())
      ON CONFLICT (id) DO NOTHING
      `,
      [
        `auth-${session.sessionID}`,
        userID,
        deviceID,
        session.sessionID,
        { provider: "apple", authorizationCodeProvided: Boolean(authorizationCode), migrated: migration.migrated },
      ]
    );

    return { user, entitlement, migration, ...session };
  });

  response.status(201).json(result);
}));

app.post("/auth/refresh", asyncHandler(async (request, response) => {
  const refreshToken = typeof request.body?.refreshToken === "string" ? request.body.refreshToken : "";
  const deviceID = typeof request.body?.deviceID === "string" ? request.body.deviceID : "";
  if (!refreshToken) {
    response.status(400).json({ error: "refreshToken is required" });
    return;
  }

  const refreshHash = hashToken(refreshToken);
  const result = await withTransaction(async (client) => {
    const sessionResult = await client.query(
      `
      SELECT id, user_id, expires_at, revoked_at
      FROM auth_sessions
      WHERE refresh_token_hash = $1
      LIMIT 1
      `,
      [refreshHash]
    );
    const current = sessionResult.rows[0];
    if (!current || current.revoked_at || new Date(current.expires_at).getTime() <= Date.now()) {
      const error = new Error("Refresh token is invalid or expired.");
      error.statusCode = 401;
      throw error;
    }

    await client.query("UPDATE auth_sessions SET revoked_at = now(), updated_at = now() WHERE id = $1", [current.id]);
    const session = await createAuthSession(client, current.user_id, deviceID, request);
    return { ...session, user: await loadAuthUser(client, current.user_id) };
  });

  response.json(result);
}));

app.post("/auth/logout", asyncHandler(async (request, response) => {
  const refreshToken = typeof request.body?.refreshToken === "string" ? request.body.refreshToken : "";
  if (refreshToken) {
    await pool.query(
      "UPDATE auth_sessions SET revoked_at = now(), updated_at = now() WHERE refresh_token_hash = $1 AND revoked_at IS NULL",
      [hashToken(refreshToken)]
    );
  }
  response.json({ ok: true });
}));

app.get("/me", requireAuth, asyncHandler(async (request, response) => {
  const [user, entitlement] = await Promise.all([
    loadAuthUser(pool, request.auth.userID),
    loadCloudEntitlement(request.auth.userID),
  ]);
  response.json({
    user,
    entitlement: entitlement ?? {
      userID: request.auth.userID,
      tier: "free",
      cloudSyncEnabled: false,
      source: "missing",
      expiresAt: null,
    },
  });
}));

app.get("/debug/summary", requireDebugSecret, async (_request, response) => {
  response.json(await debugSummary());
});

app.post("/debug/auth/mock", requireDebugSecret, asyncHandler(async (request, response) => {
  const now = new Date().toISOString();
  const email = typeof request.body?.email === "string" && request.body.email
    ? request.body.email.trim().slice(0, 160)
    : `dev-${randomUUID().slice(0, 8)}@jellytodo.local`;
  const nickname = typeof request.body?.nickname === "string" && request.body.nickname
    ? request.body.nickname.trim().slice(0, 80)
    : "Jelly Dev";
  const deviceID = typeof request.body?.deviceID === "string" && request.body.deviceID
    ? request.body.deviceID
    : randomUUID();
  const anonymousUserID = typeof request.body?.anonymousUserID === "string" ? request.body.anonymousUserID : "";
  const providerSubject = `mock:${email.toLowerCase()}`;

  const result = await withTransaction(async (client) => {
    let userID;
    const identityResult = await client.query(
      "SELECT user_id FROM auth_identities WHERE provider = 'debug_mock' AND provider_subject = $1 LIMIT 1",
      [providerSubject]
    );

    if (identityResult.rows[0]) {
      userID = identityResult.rows[0].user_id;
      await client.query(
        "UPDATE users SET email = $2, nickname = $3, updated_at = $4 WHERE id = $1",
        [userID, email, nickname, now]
      );
    } else {
      userID = randomUUID();
      await client.query(
        "INSERT INTO users (id, email, nickname, created_at, updated_at) VALUES ($1, $2, $3, $4, $4)",
        [userID, email, nickname, now]
      );
      await client.query(
        `
        INSERT INTO auth_identities (id, user_id, provider, provider_subject, email, created_at, updated_at)
        VALUES ($1, $2, 'debug_mock', $3, $4, now(), now())
        `,
        [randomUUID(), userID, providerSubject, email]
      );
    }

    const migration = await migrateAnonymousUserData(client, anonymousUserID, userID, deviceID);
    await ensureSignedInDevice(client, userID, deviceID, anonymousUserID);
    await ensureDefaultEntitlement(client, userID);

    const session = await createAuthSession(client, userID, deviceID, request);
    const entitlement = await loadCloudEntitlementWith(client, userID);
    const user = await loadAuthUser(client, userID);

    await client.query(
      `
      INSERT INTO sync_logs (
        id, user_id, device_id, entity_type, entity_id, operation, payload, created_at, synced_at
      )
      VALUES ($1, $2, $3, 'auth_session', $4, 'debug_mock_login', $5, now(), now())
      ON CONFLICT (id) DO NOTHING
      `,
      [
        `debug-auth-${session.sessionID}`,
        userID,
        deviceID,
        session.sessionID,
        { provider: "debug_mock", migrated: migration.migrated },
      ]
    );

    return { user, entitlement, migration, ...session };
  });

  response.status(201).json(result);
}));

app.post("/debug/reset", requireDebugSecret, async (_request, response) => {
  await resetDebugData();
  response.json({ ok: true });
});

app.post("/debug/seed", requireDebugSecret, async (request, response) => {
  const level = request.body?.level ?? "basic";
  const summary = await seedDebugData(level);
  response.status(201).json(summary);
});

app.post("/debug/entitlements/grant", requireDebugSecret, async (request, response) => {
  const userID = typeof request.body?.userID === "string" ? request.body.userID : "";
  if (!userID) {
    response.status(400).json({ error: "userID is required" });
    return;
  }

  await pool.query(
    `
    INSERT INTO cloud_entitlements (
      user_id, tier, cloud_sync_enabled, source, expires_at, updated_at
    )
    VALUES ($1, 'pro', true, 'debug_grant', NULL, now())
    ON CONFLICT (user_id) DO UPDATE SET
      tier = 'pro',
      cloud_sync_enabled = true,
      source = 'debug_grant',
      expires_at = NULL,
      updated_at = now()
    `,
    [userID]
  );

  response.json({ ok: true, userID, tier: "pro", cloudSyncEnabled: true });
});

app.get("/entitlements/status", async (request, response) => {
  const userID = typeof request.query.userID === "string" ? request.query.userID : "";
  if (!userID) {
    response.status(400).json({ error: "userID is required" });
    return;
  }

  const entitlement = await loadCloudEntitlement(userID);
  response.json(entitlement ?? {
    userID,
    tier: "free",
    cloudSyncEnabled: false,
    source: "missing",
    expiresAt: null,
  });
});

app.post("/entitlements/storekit/sync", async (request, response) => {
  const userID = typeof request.body?.userID === "string" ? request.body.userID : "";
  const deviceID = typeof request.body?.deviceID === "string" ? request.body.deviceID : "";
  const productID = typeof request.body?.productID === "string" ? request.body.productID : "";
  const transactionID = typeof request.body?.transactionID === "string" ? request.body.transactionID : "";
  const originalTransactionID = typeof request.body?.originalTransactionID === "string" ? request.body.originalTransactionID : "";
  const signedTransactionJWS = typeof request.body?.signedTransactionJWS === "string" ? request.body.signedTransactionJWS : "";
  const environment = typeof request.body?.environment === "string" ? request.body.environment : "unknown";
  const expirationDate = typeof request.body?.expirationDate === "string" ? request.body.expirationDate : null;

  if (!userID || !deviceID || !productID || !transactionID || !originalTransactionID || !signedTransactionJWS) {
    response.status(400).json({ error: "Missing StoreKit entitlement fields" });
    return;
  }

  if (!isKnownStoreKitProduct(productID)) {
    response.status(400).json({ error: "Unknown StoreKit product" });
    return;
  }

  const expiresAt = expirationDate ? new Date(expirationDate) : null;
  if (expiresAt && Number.isNaN(expiresAt.getTime())) {
    response.status(400).json({ error: "Invalid expirationDate" });
    return;
  }

  if (expiresAt && expiresAt.getTime() <= Date.now()) {
    response.status(402).json({ error: "StoreKit transaction is expired" });
    return;
  }

  await withTransaction(async (client) => {
    await ensureSyncIdentity(client, userID, deviceID);
    await client.query(
      `
      INSERT INTO cloud_entitlements (
        user_id, tier, cloud_sync_enabled, source, expires_at, updated_at
      )
      VALUES ($1, 'pro', true, 'storekit_client', $2, now())
      ON CONFLICT (user_id) DO UPDATE SET
        tier = 'pro',
        cloud_sync_enabled = true,
        source = 'storekit_client',
        expires_at = EXCLUDED.expires_at,
        updated_at = now()
      `,
      [userID, expiresAt ? expiresAt.toISOString() : null]
    );
    await client.query(
      `
      INSERT INTO sync_logs (
        id, user_id, device_id, entity_type, entity_id, operation, payload, created_at, synced_at
      )
      VALUES ($1, $2, $3, 'storekit_transaction', $4, 'grant_pro', $5, now(), now())
      ON CONFLICT (id) DO NOTHING
      `,
      [
        `storekit-${transactionID}`,
        userID,
        deviceID,
        transactionID,
        {
          productID,
          transactionID,
          originalTransactionID,
          environment,
          expirationDate: expiresAt ? expiresAt.toISOString() : null,
          signedTransactionJWS,
          verificationMode: "client_verified_staging",
        },
      ]
    );
  });

  response.json({
    ok: true,
    userID,
    tier: "pro",
    cloudSyncEnabled: true,
    source: "storekit_client",
    expiresAt: expiresAt ? expiresAt.toISOString() : null,
  });
});

app.get("/sync/pull", async (request, response) => {
  const since = typeof request.query.since === "string" ? request.query.since : "1970-01-01T00:00:00.000Z";
  const userID = typeof request.query.userID === "string" ? request.query.userID : "debug-user-staging";
  await assertCloudSyncAllowed(userID);

  const [plans, todos, sessions, settings] = await Promise.all([
    pool.query("SELECT * FROM plans WHERE user_id = $1 AND server_updated_at > $2 ORDER BY server_updated_at ASC", [userID, since]),
    pool.query("SELECT * FROM todo_items WHERE user_id = $1 AND server_updated_at > $2 ORDER BY server_updated_at ASC", [userID, since]),
    pool.query("SELECT * FROM pomodoro_sessions WHERE user_id = $1 AND server_updated_at > $2 ORDER BY server_updated_at ASC", [userID, since]),
    pool.query("SELECT * FROM app_settings WHERE user_id = $1 AND server_updated_at > $2 ORDER BY server_updated_at ASC", [userID, since]),
  ]);

  response.json({
    cursor: new Date().toISOString(),
    plans: plans.rows,
    todoItems: todos.rows,
    pomodoroSessions: sessions.rows,
    appSettings: settings.rows,
  });
});

function backupMetadata(row) {
  return {
    id: row.id,
    reason: row.reason,
    plansCount: row.plans_count,
    todosCount: row.todos_count,
    sessionsCount: row.sessions_count,
    createdAt: row.created_at,
  };
}

function snapshotCounts(snapshot) {
  return {
    plansCount: Array.isArray(snapshot?.planTasks) ? snapshot.planTasks.length : 0,
    todosCount: Array.isArray(snapshot?.todos) ? snapshot.todos.length : 0,
    sessionsCount: Array.isArray(snapshot?.pomodoroSessions) ? snapshot.pomodoroSessions.length : 0,
  };
}

app.get("/backup/snapshots", asyncHandler(async (request, response) => {
  const userID = typeof request.query.userID === "string" ? request.query.userID : "";
  if (!userID) {
    response.status(400).json({ error: "userID is required" });
    return;
  }

  await assertCloudSyncAllowed(userID);
  const result = await pool.query(
    `
    SELECT id, reason, plans_count, todos_count, sessions_count, created_at
    FROM backup_snapshots
    WHERE user_id = $1
    ORDER BY created_at DESC
    LIMIT 20
    `,
    [userID]
  );

  response.json({ backups: result.rows.map(backupMetadata) });
}));

app.post("/backup/snapshots", asyncHandler(async (request, response) => {
  const userID = typeof request.body?.userID === "string" ? request.body.userID : "";
  const deviceID = typeof request.body?.deviceID === "string" ? request.body.deviceID : "";
  const reason = typeof request.body?.reason === "string" ? request.body.reason.slice(0, 80) : "manual_cloud_backup";
  const snapshot = request.body?.snapshot;

  if (!userID || !deviceID || !snapshot || typeof snapshot !== "object") {
    response.status(400).json({ error: "userID, deviceID and snapshot are required" });
    return;
  }

  const backupID = randomUUID();
  const counts = snapshotCounts(snapshot);
  const result = await withTransaction(async (client) => {
    await ensureSyncIdentity(client, userID, deviceID);
    await assertCloudSyncAllowed(userID, client);
    return client.query(
      `
      INSERT INTO backup_snapshots (
        id, user_id, device_id, reason, snapshot, plans_count, todos_count, sessions_count, created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
      RETURNING id, reason, plans_count, todos_count, sessions_count, created_at
      `,
      [
        backupID,
        userID,
        deviceID,
        reason,
        snapshot,
        counts.plansCount,
        counts.todosCount,
        counts.sessionsCount,
      ]
    );
  });

  response.status(201).json({ backup: backupMetadata(result.rows[0]) });
}));

app.post("/backup/restore", asyncHandler(async (request, response) => {
  const userID = typeof request.body?.userID === "string" ? request.body.userID : "";
  const snapshotID = typeof request.body?.snapshotID === "string" ? request.body.snapshotID : "";

  if (!userID || !snapshotID) {
    response.status(400).json({ error: "userID and snapshotID are required" });
    return;
  }

  await assertCloudSyncAllowed(userID);
  const result = await pool.query(
    `
    SELECT id, snapshot
    FROM backup_snapshots
    WHERE id = $1 AND user_id = $2
    LIMIT 1
    `,
    [snapshotID, userID]
  );

  const row = result.rows[0];
  if (!row) {
    response.status(404).json({ error: "Backup snapshot not found" });
    return;
  }

  response.json({ snapshotID: row.id, snapshot: row.snapshot });
}));

const appleJWKSCache = {
  keys: null,
  expiresAt: 0,
};

function base64URLDecode(value) {
  return Buffer.from(value, "base64url");
}

function decodeJWT(token) {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid JWT format.");
  }

  return {
    header: JSON.parse(base64URLDecode(parts[0]).toString("utf8")),
    payload: JSON.parse(base64URLDecode(parts[1]).toString("utf8")),
    signingInput: `${parts[0]}.${parts[1]}`,
    signature: base64URLDecode(parts[2]),
  };
}

async function loadAppleJWKS() {
  if (appleJWKSCache.keys && appleJWKSCache.expiresAt > Date.now()) {
    return appleJWKSCache.keys;
  }

  const response = await fetch("https://appleid.apple.com/auth/keys");
  if (!response.ok) {
    throw new Error("Could not load Apple public keys.");
  }

  const body = await response.json();
  appleJWKSCache.keys = Array.isArray(body.keys) ? body.keys : [];
  appleJWKSCache.expiresAt = Date.now() + 60 * 60 * 1000;
  return appleJWKSCache.keys;
}

async function verifyAppleIdentityToken(identityToken) {
  const decoded = decodeJWT(identityToken);
  if (decoded.header.alg !== "RS256" && decoded.header.alg !== "ES256") {
    throw new Error("Unsupported Apple token algorithm.");
  }

  const keys = await loadAppleJWKS();
  const jwk = keys.find((item) => item.kid === decoded.header.kid);
  if (!jwk) {
    throw new Error("Apple public key not found.");
  }

  const key = createPublicKey({ key: jwk, format: "jwk" });
  const isValid = verify(
    decoded.header.alg === "ES256" ? "sha256" : "RSA-SHA256",
    Buffer.from(decoded.signingInput),
    decoded.header.alg === "ES256" ? { key, dsaEncoding: "ieee-p1363" } : key,
    decoded.signature
  );
  if (!isValid) {
    throw new Error("Invalid Apple identity token signature.");
  }

  const expectedAudience = process.env.APPLE_BUNDLE_ID ?? "com.zhang.JellyTodo";
  if (decoded.payload.iss !== "https://appleid.apple.com") {
    throw new Error("Invalid Apple token issuer.");
  }
  if (decoded.payload.aud !== expectedAudience) {
    throw new Error("Invalid Apple token audience.");
  }
  if (!decoded.payload.sub) {
    throw new Error("Apple token subject is missing.");
  }
  if (Number(decoded.payload.exp) * 1000 <= Date.now()) {
    throw new Error("Apple identity token is expired.");
  }

  return decoded.payload;
}

function authSecret() {
  return process.env.AUTH_JWT_SECRET ?? process.env.DEBUG_SECRET ?? "jellytodo-staging-auth-secret";
}

function signAccessToken(payload) {
  const header = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url");
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const signature = createHmac("sha256", authSecret())
    .update(`${header}.${body}`)
    .digest("base64url");
  return `${header}.${body}.${signature}`;
}

function verifyAccessToken(token) {
  const decoded = decodeJWT(token);
  const expected = createHmac("sha256", authSecret())
    .update(decoded.signingInput)
    .digest("base64url");
  if (expected !== token.split(".")[2]) {
    throw new Error("Invalid access token signature.");
  }
  if (Number(decoded.payload.exp) * 1000 <= Date.now()) {
    const error = new Error("Access token is expired.");
    error.statusCode = 401;
    throw error;
  }
  return decoded.payload;
}

function requireAuth(request, response, next) {
  const authorization = request.header("authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  if (!token) {
    response.status(401).json({ error: "Bearer token is required" });
    return;
  }

  try {
    const payload = verifyAccessToken(token);
    request.auth = {
      userID: payload.sub,
      sessionID: payload.sid,
      deviceID: payload.did,
    };
    next();
  } catch (error) {
    response.status(error.statusCode ?? 401).json({ error: error.message ?? "Invalid token" });
  }
}

function hashToken(token) {
  return createHash("sha256").update(token).digest("hex");
}

async function createAuthSession(client, userID, deviceID, request) {
  const sessionID = randomUUID();
  const now = Math.floor(Date.now() / 1000);
  const accessExpiresAtSeconds = now + 60 * 60;
  const refreshExpiresAt = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000);
  const refreshToken = randomBytes(48).toString("base64url");
  const accessToken = signAccessToken({
    sub: userID,
    sid: sessionID,
    did: deviceID,
    iat: now,
    exp: accessExpiresAtSeconds,
  });

  await client.query(
    `
    INSERT INTO auth_sessions (
      id, user_id, device_id, refresh_token_hash, user_agent, ip_address, expires_at,
      created_at, updated_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, now(), now())
    `,
    [
      sessionID,
      userID,
      deviceID,
      hashToken(refreshToken),
      request.header("user-agent") ?? "",
      request.ip ?? "",
      refreshExpiresAt.toISOString(),
    ]
  );

  return {
    sessionID,
    accessToken,
    refreshToken,
    expiresAt: new Date(accessExpiresAtSeconds * 1000).toISOString(),
  };
}

async function loadAuthUser(client, userID) {
  const result = await client.query(
    "SELECT id, email, nickname FROM users WHERE id = $1 AND deleted_at IS NULL LIMIT 1",
    [userID]
  );
  const row = result.rows[0];
  if (!row) { return null; }
  return {
    id: row.id,
    email: row.email,
    nickname: row.nickname,
  };
}

async function ensureSignedInDevice(client, userID, deviceID, anonymousUserID) {
  await client.query(
    `
    INSERT INTO devices (id, user_id, auth_user_id, anonymous_user_id, device_name, platform, last_seen_at)
    VALUES ($1, $2, $2, $3, $4, $5, now())
    ON CONFLICT (id) DO UPDATE SET
      user_id = EXCLUDED.user_id,
      auth_user_id = EXCLUDED.auth_user_id,
      anonymous_user_id = COALESCE(devices.anonymous_user_id, EXCLUDED.anonymous_user_id),
      last_seen_at = now()
    `,
    [deviceID, userID, anonymousUserID || null, "iPhone", "ios"]
  );
}

async function migrateAnonymousUserData(client, anonymousUserID, userID, deviceID) {
  if (!anonymousUserID || anonymousUserID === userID) {
    return { anonymousUserID: anonymousUserID || null, migrated: false, plans: 0, todos: 0, sessions: 0, backups: 0 };
  }

  const previous = await client.query(
    "SELECT user_id FROM account_migrations WHERE anonymous_user_id = $1 LIMIT 1",
    [anonymousUserID]
  );
  if (previous.rows[0] && previous.rows[0].user_id !== userID) {
    const error = new Error("Anonymous account has already been claimed.");
    error.statusCode = 409;
    throw error;
  }
  if (previous.rows[0]) {
    return { anonymousUserID, migrated: false, plans: 0, todos: 0, sessions: 0, backups: 0 };
  }

  const counts = await Promise.all([
    client.query("SELECT COUNT(*)::int AS count FROM plans WHERE user_id = $1", [anonymousUserID]),
    client.query("SELECT COUNT(*)::int AS count FROM todo_items WHERE user_id = $1", [anonymousUserID]),
    client.query("SELECT COUNT(*)::int AS count FROM pomodoro_sessions WHERE user_id = $1", [anonymousUserID]),
    client.query("SELECT COUNT(*)::int AS count FROM backup_snapshots WHERE user_id = $1", [anonymousUserID]),
  ]);
  const plans = counts[0].rows[0].count;
  const todos = counts[1].rows[0].count;
  const sessions = counts[2].rows[0].count;
  const backups = counts[3].rows[0].count;

  await client.query("UPDATE devices SET user_id = $2, auth_user_id = $2, anonymous_user_id = $1 WHERE user_id = $1", [anonymousUserID, userID]);
  await client.query("UPDATE plans SET user_id = $2 WHERE user_id = $1", [anonymousUserID, userID]);
  await client.query("UPDATE todo_items SET user_id = $2 WHERE user_id = $1", [anonymousUserID, userID]);
  await client.query("UPDATE pomodoro_sessions SET user_id = $2 WHERE user_id = $1", [anonymousUserID, userID]);
  await client.query("UPDATE app_settings SET user_id = $2 WHERE user_id = $1", [anonymousUserID, userID]);
  await client.query("UPDATE sync_logs SET user_id = $2 WHERE user_id = $1", [anonymousUserID, userID]);
  await client.query("UPDATE backup_snapshots SET user_id = $2 WHERE user_id = $1", [anonymousUserID, userID]);
  await client.query(
    `
    INSERT INTO cloud_entitlements (user_id, tier, cloud_sync_enabled, source, expires_at, updated_at)
    SELECT $2, tier, cloud_sync_enabled, source, expires_at, now()
    FROM cloud_entitlements
    WHERE user_id = $1
    ON CONFLICT (user_id) DO UPDATE SET
      tier = EXCLUDED.tier,
      cloud_sync_enabled = EXCLUDED.cloud_sync_enabled,
      source = EXCLUDED.source,
      expires_at = EXCLUDED.expires_at,
      updated_at = now()
    `,
    [anonymousUserID, userID]
  );
  await client.query("DELETE FROM cloud_entitlements WHERE user_id = $1", [anonymousUserID]);
  await client.query(
    `
    INSERT INTO account_migrations (
      id, anonymous_user_id, user_id, device_id, plans_count, todos_count, sessions_count, backups_count,
      created_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
    `,
    [randomUUID(), anonymousUserID, userID, deviceID, plans, todos, sessions, backups]
  );

  return { anonymousUserID, migrated: true, plans, todos, sessions, backups };
}

function shouldAutoGrantAnonymousPro() {
  return process.env.STAGING_AUTO_GRANT_PRO !== "false";
}

function isKnownStoreKitProduct(productID) {
  const configuredProducts = (process.env.STOREKIT_PRODUCT_IDS ?? "jellytodo.pro.monthly")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  return configuredProducts.includes(productID);
}

async function ensureDefaultEntitlement(client, userID) {
  const tier = shouldAutoGrantAnonymousPro() ? "pro" : "free";
  const cloudSyncEnabled = shouldAutoGrantAnonymousPro();
  const source = shouldAutoGrantAnonymousPro() ? "staging_anonymous" : "anonymous";

  await client.query(
    `
    INSERT INTO cloud_entitlements (
      user_id, tier, cloud_sync_enabled, source, expires_at, updated_at
    )
    VALUES ($1, $2, $3, $4, NULL, now())
    ON CONFLICT (user_id) DO NOTHING
    `,
    [userID, tier, cloudSyncEnabled, source]
  );
}

async function loadCloudEntitlement(userID) {
  return loadCloudEntitlementWith(pool, userID);
}

async function loadCloudEntitlementWith(client, userID) {
  const result = await client.query(
    `
    SELECT user_id, tier, cloud_sync_enabled, source, expires_at, updated_at
    FROM cloud_entitlements
    WHERE user_id = $1
    LIMIT 1
    `,
    [userID]
  );

  const row = result.rows[0];
  if (!row) { return null; }

  return {
    userID: row.user_id,
    tier: row.tier,
    cloudSyncEnabled: row.cloud_sync_enabled,
    source: row.source,
    expiresAt: row.expires_at,
    updatedAt: row.updated_at,
  };
}

async function assertCloudSyncAllowed(userID, client = pool) {
  if (userID === "debug-user-staging") {
    return;
  }

  const entitlement = await loadCloudEntitlementWith(client, userID);
  const expiresAt = entitlement?.expiresAt ? new Date(entitlement.expiresAt) : null;
  const isExpired = expiresAt ? expiresAt.getTime() <= Date.now() : false;

  if (entitlement?.tier === "pro" && entitlement.cloudSyncEnabled && !isExpired) {
    return;
  }

  const error = new Error("Cloud sync requires an active Pro entitlement.");
  error.statusCode = 402;
  throw error;
}

async function ensureSyncIdentity(client, userID, deviceID) {
  const now = new Date().toISOString();

  await client.query(
    `
    INSERT INTO users (id, nickname, created_at, updated_at)
    VALUES ($1, $2, $3, $3)
    ON CONFLICT (id) DO UPDATE SET updated_at = EXCLUDED.updated_at
    `,
    [userID, "Anonymous", now]
  );

  await client.query(
    `
    INSERT INTO devices (id, user_id, device_name, platform, last_seen_at)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (id) DO UPDATE SET last_seen_at = EXCLUDED.last_seen_at
    `,
    [deviceID, userID, "iPhone", "ios", now]
  );

  await ensureDefaultEntitlement(client, userID);
}

function parsePayload(change) {
  if (typeof change.payload === "string") {
    return JSON.parse(change.payload);
  }
  return change.payload ?? {};
}

async function mergePlan(client, userID, deviceID, change, payload) {
  if (change.operation === "delete") {
    await client.query("UPDATE plans SET deleted_at = now(), server_updated_at = now(), version = version + 1 WHERE id = $1 AND user_id = $2", [change.entityID, userID]);
    return;
  }

  await client.query(
    `
    INSERT INTO plans (
      id, user_id, device_id, title, is_collapsed, created_at, updated_at, server_updated_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, now())
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      is_collapsed = EXCLUDED.is_collapsed,
      updated_at = EXCLUDED.updated_at,
      deleted_at = NULL,
      server_updated_at = now(),
      version = plans.version + 1
    `,
    [
      change.entityID,
      userID,
      deviceID,
      payload.title ?? "Untitled",
      Boolean(payload.isCollapsed),
      payload.createdAt ?? change.createdAt,
      payload.updatedAt ?? change.createdAt,
    ]
  );
}

async function mergeTodo(client, userID, deviceID, change, payload) {
  if (change.operation === "delete") {
    await client.query("UPDATE todo_items SET deleted_at = now(), server_updated_at = now(), version = version + 1 WHERE id = $1 AND user_id = $2", [change.entityID, userID]);
    return;
  }

  await client.query(
    `
	    INSERT INTO todo_items (
	      id, user_id, device_id, plan_id, source_template_id, title, note, is_completed, is_added_to_today,
	      task_date, cycle, scheduled_dates, daily_duration_minutes, focus_timer_direction, created_at, updated_at,
	      server_updated_at
	    )
	    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb, $13, $14, $15, $16, now())
	    ON CONFLICT (id) DO UPDATE SET
	      plan_id = EXCLUDED.plan_id,
	      source_template_id = EXCLUDED.source_template_id,
	      title = EXCLUDED.title,
      note = EXCLUDED.note,
      is_completed = EXCLUDED.is_completed,
      is_added_to_today = EXCLUDED.is_added_to_today,
      task_date = EXCLUDED.task_date,
      cycle = EXCLUDED.cycle,
      scheduled_dates = EXCLUDED.scheduled_dates,
      daily_duration_minutes = EXCLUDED.daily_duration_minutes,
      focus_timer_direction = EXCLUDED.focus_timer_direction,
      updated_at = EXCLUDED.updated_at,
      deleted_at = NULL,
      server_updated_at = now(),
      version = todo_items.version + 1
    `,
    [
      change.entityID,
      userID,
	      deviceID,
	      payload.planTaskID ?? null,
	      payload.sourceTemplateID ?? null,
	      payload.title ?? "Untitled",
      payload.note ?? "",
      Boolean(payload.isCompleted),
      payload.isAddedToToday ?? true,
      payload.taskDate ?? change.createdAt,
      payload.cycle ?? "daily",
      JSON.stringify(payload.scheduledDates ?? []),
      payload.dailyDurationMinutes ?? 25,
	      payload.focusTimerDirection ?? "countDown",
	      payload.createdAt ?? change.createdAt,
	      payload.updatedAt ?? change.createdAt,
    ]
  );
}

async function mergePomodoroSession(client, userID, deviceID, change, payload) {
  if (change.operation === "delete") {
    await client.query("UPDATE pomodoro_sessions SET deleted_at = now(), server_updated_at = now(), version = version + 1 WHERE id = $1 AND user_id = $2", [change.entityID, userID]);
    return;
  }

  await client.query(
    `
	    INSERT INTO pomodoro_sessions (
	      id, user_id, device_id, plan_id, todo_id, source_template_id,
	      plan_title_snapshot, todo_title_snapshot, type, start_at, end_at, duration_seconds,
	      created_at, updated_at, server_updated_at
	    )
	    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $11, $11, now())
	    ON CONFLICT (id) DO NOTHING
    `,
    [
	      change.entityID,
	      userID,
	      deviceID,
	      payload.planTaskID ?? null,
	      payload.relatedTodoID ?? null,
	      payload.sourceTemplateID ?? null,
	      payload.planTitleSnapshot ?? "",
	      payload.todoTitleSnapshot ?? "",
	      payload.type ?? "focus",
	      payload.startAt ?? change.createdAt,
	      payload.endAt ?? change.createdAt,
      payload.durationSeconds ?? 0,
    ]
  );
}

async function mergeAppSettings(client, userID, change, payload) {
  await client.query(
    `
    INSERT INTO app_settings (
      id, user_id, theme_mode, language, haptics_enabled, pomodoro_goal_per_day,
      use_large_text, updated_at, server_updated_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
    ON CONFLICT (id) DO UPDATE SET
      theme_mode = EXCLUDED.theme_mode,
      language = EXCLUDED.language,
      haptics_enabled = EXCLUDED.haptics_enabled,
      pomodoro_goal_per_day = EXCLUDED.pomodoro_goal_per_day,
      use_large_text = EXCLUDED.use_large_text,
      updated_at = EXCLUDED.updated_at,
      server_updated_at = now(),
      version = app_settings.version + 1
    `,
    [
      `${userID}-current-settings`,
      userID,
      payload.themeMode ?? "pureWhite",
      payload.language ?? "en",
      payload.hapticsEnabled ?? true,
      payload.pomodoroGoalPerDay ?? 4,
      payload.useLargeText ?? true,
      change.createdAt,
    ]
  );
}

async function mergeChange(client, userID, deviceID, change) {
  const payload = parsePayload(change);

  if (change.entityType === "plan") {
    await mergePlan(client, userID, deviceID, change, payload);
  } else if (change.entityType === "todo_item") {
    await mergeTodo(client, userID, deviceID, change, payload);
  } else if (change.entityType === "pomodoro_session") {
    await mergePomodoroSession(client, userID, deviceID, change, payload);
  } else if (change.entityType === "app_settings") {
    await mergeAppSettings(client, userID, change, payload);
  }

  await client.query(
    `
    INSERT INTO sync_logs (
      id, user_id, device_id, entity_type, entity_id, operation, payload, created_at, synced_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
    ON CONFLICT (id) DO NOTHING
    `,
    [
      change.id,
      userID,
      deviceID,
      change.entityType,
      change.entityID,
      change.operation,
      payload,
      change.createdAt,
    ]
  );
}

app.post("/sync/push", async (request, response) => {
  const changes = Array.isArray(request.body?.changes) ? request.body.changes : [];
  const userID = typeof request.body?.userID === "string" ? request.body.userID : "debug-user-staging";
  const deviceID = typeof request.body?.deviceID === "string" ? request.body.deviceID : "debug-ios-device";

  await withTransaction(async (client) => {
    await ensureSyncIdentity(client, userID, deviceID);
    await assertCloudSyncAllowed(userID, client);
    for (const change of changes) {
      await mergeChange(client, userID, deviceID, change);
    }
  });

  response.status(202).json({
    accepted: changes.length,
    cursor: new Date().toISOString(),
  });
});

app.use((error, _request, response, _next) => {
  console.error(error);
  response.status(error.statusCode ?? 500).json({
    error: error.message ?? "Internal server error",
  });
});

await initSchema();

app.listen(port, () => {
  console.log(`JellyTodo cloud API listening on :${port}`);
});

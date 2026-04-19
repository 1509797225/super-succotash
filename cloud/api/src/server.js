import "dotenv/config";
import express from "express";
import cors from "cors";
import { randomUUID } from "node:crypto";
import { initSchema, pool } from "./db.js";
import { debugSummary, resetDebugData, seedDebugData } from "./seed.js";

const app = express();
const port = Number(process.env.PORT ?? 3000);

app.use(cors());
app.use(express.json({ limit: "2mb" }));

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

  await pool.query(
    "INSERT INTO users (id, nickname, created_at, updated_at) VALUES ($1, $2, $3, $3)",
    [userID, "Anonymous", now]
  );
  await pool.query(
    "INSERT INTO devices (id, user_id, device_name, platform, last_seen_at) VALUES ($1, $2, $3, $4, $5)",
    [deviceID, userID, "iPhone", "ios", now]
  );

  response.status(201).json({ userID, deviceID });
});

app.get("/debug/summary", requireDebugSecret, async (_request, response) => {
  response.json(await debugSummary());
});

app.post("/debug/reset", requireDebugSecret, async (_request, response) => {
  await resetDebugData();
  response.json({ ok: true });
});

app.post("/debug/seed", requireDebugSecret, async (request, response) => {
  const level = request.body?.level ?? "basic";
  const summary = await seedDebugData(level);
  response.status(201).json(summary);
});

app.get("/sync/pull", async (request, response) => {
  const since = typeof request.query.since === "string" ? request.query.since : "1970-01-01T00:00:00.000Z";
  const userID = typeof request.query.userID === "string" ? request.query.userID : "debug-user-staging";

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

app.post("/sync/push", async (request, response) => {
  const changes = Array.isArray(request.body?.changes) ? request.body.changes : [];
  response.status(202).json({
    accepted: changes.length,
    message: "Sync push shape accepted. Merge implementation will be added after iOS local SQLite migration.",
  });
});

app.use((error, _request, response, _next) => {
  console.error(error);
  response.status(500).json({
    error: error.message ?? "Internal server error",
  });
});

await initSchema();

app.listen(port, () => {
  console.log(`JellyTodo cloud API listening on :${port}`);
});

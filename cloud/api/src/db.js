import pg from "pg";

const { Pool } = pg;

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export async function initSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT,
      nickname TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL
    );

    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_name TEXT NOT NULL DEFAULT '',
      platform TEXT NOT NULL DEFAULT 'ios',
      last_seen_at TIMESTAMPTZ NOT NULL
    );

    CREATE TABLE IF NOT EXISTS plans (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
      title TEXT NOT NULL,
      is_collapsed BOOLEAN NOT NULL DEFAULT false,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL,
      deleted_at TIMESTAMPTZ,
      server_created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      version INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS todo_items (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
      plan_id TEXT REFERENCES plans(id) ON DELETE SET NULL,
      title TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      is_completed BOOLEAN NOT NULL DEFAULT false,
      is_added_to_today BOOLEAN NOT NULL DEFAULT true,
      task_date TIMESTAMPTZ NOT NULL,
      cycle TEXT NOT NULL DEFAULT 'daily',
      daily_duration_minutes INTEGER NOT NULL DEFAULT 25,
      focus_timer_direction TEXT NOT NULL DEFAULT 'countDown',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL,
      deleted_at TIMESTAMPTZ,
      server_created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      version INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS pomodoro_sessions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
      plan_id TEXT REFERENCES plans(id) ON DELETE SET NULL,
      todo_id TEXT REFERENCES todo_items(id) ON DELETE SET NULL,
      type TEXT NOT NULL,
      start_at TIMESTAMPTZ NOT NULL,
      end_at TIMESTAMPTZ NOT NULL,
      duration_seconds INTEGER NOT NULL,
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL,
      deleted_at TIMESTAMPTZ,
      server_created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      version INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS app_settings (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      theme_mode TEXT NOT NULL DEFAULT 'pureWhite',
      language TEXT NOT NULL DEFAULT 'english',
      haptics_enabled BOOLEAN NOT NULL DEFAULT true,
      pomodoro_goal_per_day INTEGER NOT NULL DEFAULT 4,
      use_large_text BOOLEAN NOT NULL DEFAULT true,
      updated_at TIMESTAMPTZ NOT NULL,
      server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      version INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS sync_logs (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      device_id TEXT,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload JSONB NOT NULL,
      created_at TIMESTAMPTZ NOT NULL,
      synced_at TIMESTAMPTZ
    );

    CREATE INDEX IF NOT EXISTS idx_plans_user_updated ON plans(user_id, server_updated_at);
    CREATE INDEX IF NOT EXISTS idx_todo_user_updated ON todo_items(user_id, server_updated_at);
    CREATE INDEX IF NOT EXISTS idx_todo_plan_id ON todo_items(plan_id);
    CREATE INDEX IF NOT EXISTS idx_todo_task_date ON todo_items(task_date);
    CREATE INDEX IF NOT EXISTS idx_pomodoro_user_updated ON pomodoro_sessions(user_id, server_updated_at);
    CREATE INDEX IF NOT EXISTS idx_pomodoro_end_at ON pomodoro_sessions(end_at);
    CREATE INDEX IF NOT EXISTS idx_pomodoro_todo_id ON pomodoro_sessions(todo_id);
  `);
}

export async function withTransaction(callback) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await callback(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

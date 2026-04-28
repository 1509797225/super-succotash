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
      avatar_url TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL,
      deleted_at TIMESTAMPTZ
    );

    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_name TEXT NOT NULL DEFAULT '',
      platform TEXT NOT NULL DEFAULT 'ios',
      auth_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      anonymous_user_id TEXT,
      last_seen_at TIMESTAMPTZ NOT NULL
    );

    CREATE TABLE IF NOT EXISTS auth_identities (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      provider TEXT NOT NULL,
      provider_subject TEXT NOT NULL,
      email TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE(provider, provider_subject)
    );

    CREATE TABLE IF NOT EXISTS auth_sessions (
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

    CREATE TABLE IF NOT EXISTS account_migrations (
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

    CREATE TABLE IF NOT EXISTS cloud_entitlements (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      tier TEXT NOT NULL DEFAULT 'free',
      cloud_sync_enabled BOOLEAN NOT NULL DEFAULT false,
      source TEXT NOT NULL DEFAULT 'server',
      expires_at TIMESTAMPTZ,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
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
	      source_template_id TEXT REFERENCES todo_items(id) ON DELETE SET NULL,
	      title TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      is_completed BOOLEAN NOT NULL DEFAULT false,
      is_added_to_today BOOLEAN NOT NULL DEFAULT true,
      task_date TIMESTAMPTZ NOT NULL,
      cycle TEXT NOT NULL DEFAULT 'daily',
      schedule_mode TEXT NOT NULL DEFAULT 'custom',
      recurrence_value INTEGER,
      scheduled_dates JSONB NOT NULL DEFAULT '[]'::jsonb,
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
	      source_template_id TEXT REFERENCES todo_items(id) ON DELETE SET NULL,
	      plan_title_snapshot TEXT NOT NULL DEFAULT '',
	      todo_title_snapshot TEXT NOT NULL DEFAULT '',
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

    CREATE TABLE IF NOT EXISTS backup_snapshots (
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

    CREATE INDEX IF NOT EXISTS idx_plans_user_updated ON plans(user_id, server_updated_at);
    CREATE INDEX IF NOT EXISTS idx_todo_user_updated ON todo_items(user_id, server_updated_at);
    CREATE INDEX IF NOT EXISTS idx_todo_plan_id ON todo_items(plan_id);
    CREATE INDEX IF NOT EXISTS idx_todo_task_date ON todo_items(task_date);
    CREATE INDEX IF NOT EXISTS idx_pomodoro_user_updated ON pomodoro_sessions(user_id, server_updated_at);
    CREATE INDEX IF NOT EXISTS idx_pomodoro_end_at ON pomodoro_sessions(end_at);
    CREATE INDEX IF NOT EXISTS idx_pomodoro_todo_id ON pomodoro_sessions(todo_id);
    CREATE INDEX IF NOT EXISTS idx_cloud_entitlements_sync ON cloud_entitlements(user_id, cloud_sync_enabled);
    CREATE INDEX IF NOT EXISTS idx_backup_snapshots_user_created ON backup_snapshots(user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_auth_sessions_user ON auth_sessions(user_id, revoked_at, expires_at);

    ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
	    ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
	    ALTER TABLE devices ADD COLUMN IF NOT EXISTS auth_user_id TEXT REFERENCES users(id) ON DELETE SET NULL;
	    ALTER TABLE devices ADD COLUMN IF NOT EXISTS anonymous_user_id TEXT;
	  ALTER TABLE todo_items ADD COLUMN IF NOT EXISTS source_template_id TEXT REFERENCES todo_items(id) ON DELETE SET NULL;
	  ALTER TABLE todo_items ADD COLUMN IF NOT EXISTS schedule_mode TEXT NOT NULL DEFAULT 'custom';
	  ALTER TABLE todo_items ADD COLUMN IF NOT EXISTS recurrence_value INTEGER;
	  ALTER TABLE todo_items ADD COLUMN IF NOT EXISTS scheduled_dates JSONB NOT NULL DEFAULT '[]'::jsonb;
	  ALTER TABLE pomodoro_sessions ADD COLUMN IF NOT EXISTS source_template_id TEXT REFERENCES todo_items(id) ON DELETE SET NULL;
	    ALTER TABLE pomodoro_sessions ADD COLUMN IF NOT EXISTS plan_title_snapshot TEXT NOT NULL DEFAULT '';
	    ALTER TABLE pomodoro_sessions ADD COLUMN IF NOT EXISTS todo_title_snapshot TEXT NOT NULL DEFAULT '';
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

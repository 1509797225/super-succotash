import "dotenv/config";
import { randomUUID } from "node:crypto";
import { initSchema, pool, withTransaction } from "./db.js";

const DEBUG_USER_ID = "debug-user-staging";
const DEBUG_DEVICE_ID = "debug-device-staging";

const LEVELS = {
  basic: { planCount: 6, itemsPerPlan: 4, sessionsPerTodo: 2, todayItemsPerPlan: 3 },
  medium: { planCount: 10, itemsPerPlan: 5, sessionsPerTodo: 1, todayItemsPerPlan: 4 },
  large: { planCount: 12, itemsPerPlan: 10, sessionsPerTodo: 2, todayItemsPerPlan: 5 },
  heavy: { planCount: 20, itemsPerPlan: 15, sessionsPerTodo: 2, todayItemsPerPlan: 6 },
};

const planTitles = [
  "考研数学", "考研英语", "考研政治", "专业课一", "专业课二",
  "SwiftUI 项目", "产品设计", "阅读计划", "健身恢复", "生活整理",
  "算法训练", "写作输出", "英语听力", "财务复盘", "睡眠管理",
  "摄影练习", "面试准备", "论文阅读", "副业计划", "周末清单",
];

const taskTitles = [
  "高数极限", "线代矩阵", "概率分布", "阅读精翻", "核心词汇",
  "马原框架", "专业课真题", "数据结构", "操作系统", "UI 走查",
  "交互复盘", "组件封装", "跑步训练", "力量拉伸", "房间整理",
  "读书笔记", "文章草稿", "算法错题", "听力影子跟读", "预算记录",
  "睡前复盘", "照片整理", "面试八股", "论文摘要", "周计划拆解",
];

function iso(date) {
  return date.toISOString();
}

function addDays(date, days) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

function makeSessionEnd(now, planIndex, itemIndex, sessionIndex) {
  const dayOffset = -((planIndex * 3 + itemIndex + sessionIndex) % 34);
  const hour = (7 + planIndex * 2 + itemIndex * 3 + sessionIndex * 5) % 24;
  const minute = (itemIndex * 11 + sessionIndex * 17) % 60;
  const end = addDays(now, dayOffset);
  end.setHours(hour, minute, 0, 0);
  return end;
}

async function ensureDebugIdentity(client, now) {
  await client.query(
    `
    INSERT INTO users (id, email, nickname, created_at, updated_at)
    VALUES ($1, $2, $3, $4, $4)
    ON CONFLICT (id) DO UPDATE SET
      nickname = EXCLUDED.nickname,
      updated_at = EXCLUDED.updated_at
    `,
    [DEBUG_USER_ID, "debug@jellytodo.local", "JellyTodo Debug", iso(now)]
  );

  await client.query(
    `
    INSERT INTO devices (id, user_id, device_name, platform, last_seen_at)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (id) DO UPDATE SET
      last_seen_at = EXCLUDED.last_seen_at
    `,
    [DEBUG_DEVICE_ID, DEBUG_USER_ID, "Cloud Staging Seeder", "server", iso(now)]
  );
}

export async function resetDebugData() {
  await initSchema();
  await withTransaction(async (client) => {
    await client.query("DELETE FROM sync_logs WHERE user_id = $1", [DEBUG_USER_ID]);
    await client.query("DELETE FROM pomodoro_sessions WHERE user_id = $1", [DEBUG_USER_ID]);
    await client.query("DELETE FROM todo_items WHERE user_id = $1", [DEBUG_USER_ID]);
    await client.query("DELETE FROM plans WHERE user_id = $1", [DEBUG_USER_ID]);
    await client.query("DELETE FROM app_settings WHERE user_id = $1", [DEBUG_USER_ID]);
    await client.query("DELETE FROM devices WHERE user_id = $1", [DEBUG_USER_ID]);
    await client.query("DELETE FROM users WHERE id = $1", [DEBUG_USER_ID]);
  });
}

export async function seedDebugData(levelName = "basic") {
  const level = LEVELS[levelName];
  if (!level) {
    throw new Error(`Unknown seed level: ${levelName}`);
  }

  await initSchema();
  await resetDebugData();

  const now = new Date();
  let planTotal = 0;
  let todoTotal = 0;
  let todayTodoTotal = 0;
  let sessionTotal = 0;
  let focusSecondsTotal = 0;

  await withTransaction(async (client) => {
    await ensureDebugIdentity(client, now);

    await client.query(
      `
      INSERT INTO app_settings (
        id, user_id, theme_mode, language, haptics_enabled,
        pomodoro_goal_per_day, use_large_text, updated_at
      )
      VALUES ($1, $2, $3, $4, true, $5, true, $6)
      `,
      [randomUUID(), DEBUG_USER_ID, "pureWhite", "chinese", 8, iso(now)]
    );

    for (let planIndex = 0; planIndex < level.planCount; planIndex += 1) {
      const planID = randomUUID();
      const planTitle = planTitles[planIndex % planTitles.length];
      const planCreated = addDays(now, -planIndex);
      planTotal += 1;

      await client.query(
        `
        INSERT INTO plans (
          id, user_id, device_id, title, is_collapsed, sort_order,
          created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, false, $5, $6, $6)
        `,
        [planID, DEBUG_USER_ID, DEBUG_DEVICE_ID, planTitle, planIndex, iso(planCreated)]
      );

      for (let itemIndex = 0; itemIndex < level.itemsPerPlan; itemIndex += 1) {
        const todoID = randomUUID();
        const title = `${planTitle} · ${taskTitles[(planIndex + itemIndex) % taskTitles.length]}`;
        const isToday = itemIndex < level.todayItemsPerPlan;
        const isCompleted = (planIndex + itemIndex) % 4 === 0;
        const taskDate = isToday ? now : addDays(now, -((itemIndex % 12) + 1));
        const dailyDuration = [15, 25, 35, 45, 60, 90][(planIndex + itemIndex) % 6];
        const direction = (planIndex + itemIndex) % 3 === 0 ? "countUp" : "countDown";
        todoTotal += 1;
        if (isToday) todayTodoTotal += 1;

        await client.query(
          `
          INSERT INTO todo_items (
            id, user_id, device_id, plan_id, title, note, is_completed,
            is_added_to_today, task_date, cycle, scheduled_dates, daily_duration_minutes,
            focus_timer_direction, sort_order, created_at, updated_at
          )
          VALUES (
            $1, $2, $3, $4, $5, $6, $7,
            $8, $9, $10, $11::jsonb, $12,
            $13, $14, $15, $15
          )
          `,
          [
            todoID,
            DEBUG_USER_ID,
            DEBUG_DEVICE_ID,
            planID,
            title,
            `Staging seed data for ${levelName}.`,
            isCompleted,
            isToday,
            iso(taskDate),
            ["once", "daily", "weekly", "monthly"][(planIndex + itemIndex) % 4],
            JSON.stringify([iso(taskDate)]),
            dailyDuration,
            direction,
            itemIndex,
            iso(addDays(now, -((planIndex + itemIndex) % 20))),
          ]
        );

        for (let sessionIndex = 0; sessionIndex < level.sessionsPerTodo; sessionIndex += 1) {
          const durationMinutes = Math.max(10, dailyDuration - ((sessionIndex + itemIndex) % 4) * 5);
          const endAt = makeSessionEnd(now, planIndex, itemIndex, sessionIndex);
          const startAt = addMinutes(endAt, -durationMinutes);
          const durationSeconds = durationMinutes * 60;
          sessionTotal += 1;
          focusSecondsTotal += durationSeconds;

          await client.query(
            `
            INSERT INTO pomodoro_sessions (
              id, user_id, device_id, plan_id, todo_id, type,
              start_at, end_at, duration_seconds, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, 'focus', $6, $7, $8, $7, $7)
            `,
            [
              randomUUID(),
              DEBUG_USER_ID,
              DEBUG_DEVICE_ID,
              planID,
              todoID,
              iso(startAt),
              iso(endAt),
              durationSeconds,
            ]
          );
        }
      }
    }
  });

  return {
    level: levelName,
    userID: DEBUG_USER_ID,
    plans: planTotal,
    todos: todoTotal,
    todayTodos: todayTodoTotal,
    sessions: sessionTotal,
    focusSeconds: focusSecondsTotal,
  };
}

export async function debugSummary() {
  await initSchema();
  const result = await pool.query(
    `
    SELECT
      (SELECT count(*)::int FROM plans WHERE user_id = $1) AS plans,
      (SELECT count(*)::int FROM todo_items WHERE user_id = $1) AS todos,
      (SELECT count(*)::int FROM todo_items WHERE user_id = $1 AND is_added_to_today = true AND task_date::date = CURRENT_DATE) AS today_todos,
      (SELECT count(*)::int FROM pomodoro_sessions WHERE user_id = $1) AS sessions,
      (SELECT coalesce(sum(duration_seconds), 0)::int FROM pomodoro_sessions WHERE user_id = $1 AND type = 'focus') AS focus_seconds
    `,
    [DEBUG_USER_ID]
  );
  return result.rows[0];
}

if (process.argv[1]?.endsWith("seed.js")) {
  const command = process.argv[2] ?? "basic";
  try {
    if (command === "reset") {
      await resetDebugData();
      console.log("Reset staging debug data.");
    } else {
      const summary = await seedDebugData(command);
      console.log(JSON.stringify(summary, null, 2));
    }
  } finally {
    await pool.end();
  }
}

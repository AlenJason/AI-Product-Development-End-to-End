// Chạy bản build (dist/) như server thật để bắt lỗi asset, ESM và luồng HTTP.
// Dùng DB trong RAM, đăng nhập giả lập và không gọi Gemini thật.
import { readFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';

const PORT = process.env.SMOKE_PORT ?? '3999';
const BASE = `http://127.0.0.1:${PORT}`;
const STARTUP_TIMEOUT_MS = 20_000;
const REQUIRED_ASSETS = [
  'dist/plan/data/swap-meals.json',
  'dist/plan/data/swap-exercises.json',
  'dist/plan/data/restriction-keywords.json',
];

for (const asset of REQUIRED_ASSETS) {
  try {
    JSON.parse(readFileSync(asset, 'utf-8'));
  } catch (error) {
    throw new Error(`Build thiếu asset hoặc JSON không hợp lệ: ${asset}`, { cause: error });
  }
}

const server = spawn(process.execPath, ['dist/main.js'], {
  env: {
    ...process.env,
    PORT,
    NODE_ENV: 'test',
    DB_TYPE: 'sqlite',
    DATABASE_PATH: ':memory:',
    AUTH_MODE: 'mock',
    GOOGLE_CLIENT_ID: '',
    JWT_SECRET: '',
    JWT_EXPIRES_IN: '',
    ALLOW_MOCK_AUTH: '',
    GEMINI_API_KEY: '',
    PLAN_AI_PROVIDER: 'groq',
    GROQ_API_KEY: '',
    GEMINI_BASE_URL: '',
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let output = '';
server.stdout.on('data', (chunk) => (output += chunk));
server.stderr.on('data', (chunk) => (output += chunk));
const exited = new Promise((resolve) => server.on('exit', resolve));

async function call(method, path, { token, body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

function expect(condition, message) {
  if (!condition) throw new Error(message);
}

async function post(path, body, token) {
  return call('POST', `/api/v1/${path}`, { token, body });
}

async function login(email) {
  const response = await post('auth/google', { id_token: `mock:${email}` });
  expect(response.status === 200 && response.body.access_token, `Đăng nhập ${email} lỗi: ${response.status}`);
  return response.body.access_token;
}

async function historyDetail(planId, token) {
  return call('GET', `/api/v1/plans/history/${planId}`, { token });
}

async function waitForServer() {
  const deadline = Date.now() + STARTUP_TIMEOUT_MS;
  while (Date.now() < deadline) {
    if (server.exitCode !== null) throw new Error(`Server thoát sớm (mã ${server.exitCode})`);
    try {
      return await call('GET', '/health');
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }
  throw new Error(`Server không lên sau ${STARTUP_TIMEOUT_MS} ms`);
}

try {
  const health = await waitForServer();
  expect(health.status === 200 && health.body.auth_mode === 'mock', `/health sai: ${JSON.stringify(health)}`);

  const profile = { age: 22, gender: 'female', height_cm: 168, weight_kg: 62, activity_level: 'light', goal: 'cut' };
  const guestPlanResponse = await post('generate-plan', profile);
  expect(guestPlanResponse.status === 200 && guestPlanResponse.body.source === 'sample', 'generate-plan guest lỗi');
  const guestPlan = guestPlanResponse.body;

  const guestMeal = await post('meals/swap', { profile, plan: guestPlan, meal_id: 'm2_2' });
  expect(guestMeal.status === 200 && guestMeal.body.plan.plan_id === guestPlan.plan_id, `Đổi món guest lỗi: ${guestMeal.status}`);

  const guestExercise = await post('exercises/swap', { profile, plan: guestPlan, exercise_id: 'e1_2' });
  expect(
    guestExercise.status === 200 && guestExercise.body.plan.plan_id === guestPlan.plan_id,
    `Đổi bài tập guest lỗi: ${guestExercise.status}`,
  );

  const guestFeedback = await post('feedback', {
    profile,
    plan: guestPlan,
    day_number: 1,
    intensity: 'hard',
    body_states: ['normal'],
    eating: 'on_plan',
  });
  expect(
    guestFeedback.status === 200 &&
      guestFeedback.body.plan.plan_id === guestPlan.plan_id &&
      guestFeedback.body.safety_warning === null,
    `Feedback guest lỗi: ${guestFeedback.status}`,
  );

  for (const [path, body] of [
    ['meals/swap', { profile, plan: guestPlan, meal_id: 'm2_2' }],
    ['exercises/swap', { profile, plan: guestPlan, exercise_id: 'e1_2' }],
    [
      'feedback',
      {
        profile,
        plan: guestPlan,
        day_number: 1,
        intensity: 'moderate',
        body_states: ['normal'],
        eating: 'on_plan',
      },
    ],
  ]) {
    const invalidToken = await post(path, body, 'invalid-smoke-token');
    expect(invalidToken.status === 401, `${path} phải từ chối token sai, nhận ${invalidToken.status}`);
  }

  const ownerToken = await login('smoke-owner@vku.edu.vn');
  const planResponse = await post('generate-plan', profile, ownerToken);
  expect(planResponse.status === 200 && planResponse.body.source === 'sample', 'generate-plan đăng nhập lỗi');
  let plan = planResponse.body;
  const initialPlanId = plan.plan_id;
  let detail = await historyDetail(initialPlanId, ownerToken);
  expect(detail.status === 200 && detail.body.plan_id === initialPlanId, 'Plan mới chưa được lưu vào lịch sử');

  const meal = await post('meals/swap', { profile, plan, meal_id: 'm2_2' }, ownerToken);
  expect(meal.status === 200 && meal.body.plan.plan_id === initialPlanId, `Đổi món đăng nhập lỗi: ${meal.status}`);
  plan = meal.body.plan;

  const exercise = await post('exercises/swap', { profile, plan, exercise_id: 'e1_2' }, ownerToken);
  expect(
    exercise.status === 200 && exercise.body.plan.plan_id === initialPlanId,
    `Đổi bài tập đăng nhập lỗi: ${exercise.status}`,
  );
  plan = exercise.body.plan;

  const feedback = await post(
    'feedback',
    {
      profile,
      plan,
      day_number: 1,
      intensity: 'hard',
      body_states: ['normal'],
      eating: 'on_plan',
    },
    ownerToken,
  );
  expect(
    feedback.status === 200 && feedback.body.plan.plan_id === initialPlanId,
    `Feedback cập nhật plan lỗi: ${feedback.status}`,
  );
  plan = feedback.body.plan;
  detail = await historyDetail(initialPlanId, ownerToken);
  expect(
    detail.status === 200 && isDeepStrictEqual(detail.body, plan),
    'Lịch sử không phản ánh plan sau feedback',
  );

  const otherToken = await login('smoke-other@vku.edu.vn');
  const beforeOtherUser = detail.body;
  const foreignFeedback = await post(
    'feedback',
    {
      profile,
      plan,
      day_number: 1,
      intensity: 'hard',
      body_states: ['normal'],
      eating: 'on_plan',
    },
    otherToken,
  );
  expect(foreignFeedback.status === 200, `Feedback plan khác chủ lỗi: ${foreignFeedback.status}`);
  detail = await historyDetail(initialPlanId, ownerToken);
  expect(
    detail.status === 200 && isDeepStrictEqual(detail.body, beforeOtherUser),
    'Feedback của tài khoản khác đã làm thay đổi plan của chủ sở hữu',
  );
  const otherHistory = await call('GET', '/api/v1/plans/history', { token: otherToken });
  expect(
    otherHistory.status === 200 && !otherHistory.body.plans.some((item) => item.id === initialPlanId),
    'Plan của người khác xuất hiện trong lịch sử tài khoản hiện tại',
  );

  const dayThree = await post(
    'feedback',
    {
      profile,
      plan,
      day_number: 3,
      intensity: 'moderate',
      body_states: ['normal'],
      eating: 'on_plan',
    },
    ownerToken,
  );
  expect(
    dayThree.status === 200 && dayThree.body.plan.plan_id !== initialPlanId,
    `Feedback ngày 3 không tạo plan mới: ${dayThree.status}`,
  );
  const savedNewPlan = await historyDetail(dayThree.body.plan.plan_id, ownerToken);
  expect(
    savedNewPlan.status === 200 && savedNewPlan.body.plan_id === dayThree.body.plan.plan_id,
    'Plan mới từ feedback ngày 3 chưa được lưu vào lịch sử',
  );

  console.log(
    'Smoke test đạt: health, đăng nhập, generate-plan, history, ba endpoint Phase 4 (guest/auth), quyền sở hữu và feedback ngày 3.',
  );
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Smoke test thất bại: ${message}\n--- log server ---\n${output}`);
  process.exitCode = 1;
} finally {
  if (server.exitCode === null) server.kill();
  await exited;
}

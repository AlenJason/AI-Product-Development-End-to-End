// Chạy bản build (dist/) như server thật rồi gọi thử các endpoint chính.
// Bắt những lỗi vitest không thấy vì vitest chạy thẳng file .ts: asset chưa được copy vào dist
// (nest-cli.json), import vòng giữa các entity khi chạy ESM đã build, gói CommonJS require() NestJS 12 (chỉ có ESM) —
// Node 24 cho phép, bộ nạp module của Vercel thì không, nên server chạy với --no-experimental-require-module như Vercel.
// Chạy hai lần: `node dist/main.js` (máy dev, start:prod) và import như runtime của Vercel (vercel-handler-server.mjs).
// Không cần khoá nào: DB trong RAM, đăng nhập giả lập, không có Gemini (#17).
import { spawn } from 'node:child_process';

const PORT = process.env.SMOKE_PORT ?? '3999';
const BASE = `http://127.0.0.1:${PORT}`;
const STARTUP_TIMEOUT_MS = 20_000;

const MODES = [
  ['node dist/main.js', 'dist/main.js'],
  ['như trên Vercel', 'scripts/vercel-handler-server.mjs'],
];

function startServer(script) {
  const server = spawn(process.execPath, ['--no-experimental-require-module', script], {
    env: {
      ...process.env,
      PORT,
      NODE_ENV: 'test',
      DATABASE_PATH: ':memory:',
      DATABASE_URL: '',
      AUTH_MODE: 'mock',
      GOOGLE_CLIENT_ID: '',
      JWT_SECRET: '',
      JWT_EXPIRES_IN: '',
      ALLOW_MOCK_AUTH: '',
      GEMINI_API_KEY: '',
      GEMINI_BASE_URL: '',
      GEMINI_THINKING: '',
      GEMINI_TOTAL_TIMEOUT_MS: '',
      // Rộng để không chặn, nhưng bộ đếm trong DB (SQL thô) vẫn chạy thật trên bản build.
      RATE_LIMIT_PLAN: '100/1m',
      RATE_LIMIT_ADJUST: '100/1m',
      TRUST_PROXY_HOPS: '',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const state = { server, output: '', exited: new Promise((resolve) => server.on('exit', resolve)) };
  server.stdout.on('data', (chunk) => (state.output += chunk));
  server.stderr.on('data', (chunk) => (state.output += chunk));
  return state;
}

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

async function waitForServer(server) {
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

async function checkEndpoints(server) {
  const health = await waitForServer(server);
  expect(health.status === 200 && health.body.auth_mode === 'mock', `/health sai: ${JSON.stringify(health)}`);

  const login = await call('POST', '/api/v1/auth/google', { body: { id_token: 'mock:smoke@vku.edu.vn' } });
  expect(login.status === 200 && login.body.access_token, `Đăng nhập giả lập lỗi: ${login.status}`);
  const token = login.body.access_token;

  const profile = { age: 22, gender: 'female', height_cm: 168, weight_kg: 62, activity_level: 'light', goal: 'cut' };
  const plan = await call('POST', '/api/v1/generate-plan', { token, body: profile });
  expect(plan.status === 200 && plan.body.source === 'sample', `generate-plan lỗi: ${plan.status}`);

  const history = await call('GET', '/api/v1/plans/history', { token });
  expect(history.status === 200 && history.body.plans[0]?.id === plan.body.plan_id, 'Plan không có trong lịch sử');

  const detail = await call('GET', `/api/v1/plans/history/${plan.body.plan_id}`, { token });
  expect(detail.status === 200 && detail.body.plan_id === plan.body.plan_id, `Xem lại plan lỗi: ${detail.status}`);

  // Giai đoạn 4: ba endpoint này đọc swap-meals.json, swap-exercises.json, restriction-keywords.json từ dist/.
  const adjust = { profile, plan: plan.body };
  const meal = await call('POST', '/api/v1/meals/swap', { token, body: { ...adjust, meal_id: 'm1_2' } });
  expect(meal.status === 200 && meal.body.plan.plan_id === plan.body.plan_id, `Đổi món lỗi: ${meal.status}`);
  const exercise = await call('POST', '/api/v1/exercises/swap', { token, body: { ...adjust, exercise_id: 'e1_2' } });
  expect(exercise.status === 200, `Đổi bài tập lỗi: ${exercise.status}`);
  const feedback = await call('POST', '/api/v1/feedback', {
    token,
    body: { ...adjust, day_number: 1, intensity: 'hard', body_states: ['danger_sign'], eating: 'on_plan' },
  });
  expect(feedback.status === 200 && feedback.body.safety_warning, `Feedback lỗi: ${feedback.status}`);
}

for (const [label, script] of MODES) {
  const state = startServer(script);
  try {
    await checkEndpoints(state.server);
    console.log(`Smoke test đạt (${label}): /health, đăng nhập giả lập, generate-plan, lịch sử, đổi món, đổi bài tập, feedback.`);
  } catch (error) {
    console.error(`Smoke test thất bại (${label}): ${error.message}\n--- log server ---\n${state.output}`);
    process.exitCode = 1;
  } finally {
    state.server.kill();
    await state.exited;
  }
  if (process.exitCode) break;
}

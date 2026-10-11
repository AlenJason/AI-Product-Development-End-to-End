// Chạy bản build (dist/) như server thật rồi gọi thử các endpoint chính.
// Bắt những lỗi vitest không thấy vì vitest chạy thẳng file .ts: asset chưa được copy vào dist
// (nest-cli.json), import vòng giữa các entity khi chạy ESM đã build.
// Không cần khoá nào: DB trong RAM, đăng nhập giả lập, không có Gemini (#17).
import { spawn } from 'node:child_process';

const PORT = process.env.SMOKE_PORT ?? '3999';
const BASE = `http://127.0.0.1:${PORT}`;
const STARTUP_TIMEOUT_MS = 20_000;

const server = spawn(process.execPath, ['dist/main.js'], {
  env: {
    ...process.env,
    PORT,
    NODE_ENV: 'test',
    DATABASE_PATH: ':memory:',
    AUTH_MODE: 'mock',
    GOOGLE_CLIENT_ID: '',
    JWT_SECRET: '',
    JWT_EXPIRES_IN: '',
    ALLOW_MOCK_AUTH: '',
    GEMINI_API_KEY: '',
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

  console.log('Smoke test đạt: /health, đăng nhập giả lập, generate-plan, lịch sử.');
} catch (error) {
  console.error(`Smoke test thất bại: ${error.message}\n--- log server ---\n${output}`);
  process.exitCode = 1;
} finally {
  server.kill();
  await exited;
}

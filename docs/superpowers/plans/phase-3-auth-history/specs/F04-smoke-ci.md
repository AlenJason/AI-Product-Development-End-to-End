# F04 — Smoke test trên bản build + CI

## Feature

Unit test và e2e đều chạy qua vitest, tức là chạy thẳng file `.ts`. Có những lỗi chỉ xuất hiện khi chạy bản build (`dist/`) như server thật, và vitest không thấy:

- File không phải `.ts` chưa khai báo trong `nest-cli.json` → không có trong `dist/` (từng gây `ENOENT` với `sample-plan.json` lúc mới dựng khung, #5).
- Import vòng giữa entity khi thiếu `Relation<>` → `ReferenceError` lúc khởi động (phát hiện khi lập plan này, xem F01). Khi đó 126 unit test và 36 e2e vẫn xanh.

`npm run test:smoke` chạy `node dist/main.js` với DB trong RAM, đăng nhập giả lập, không Gemini, rồi gọi `/health` → đăng nhập → `generate-plan` → danh sách lịch sử → xem lại plan. Server không lên hoặc một bước sai → in log server và thoát mã 1. CI chạy bước này sau e2e.

## Scope

CI + script:

- `backend_api/scripts/smoke-test.mjs` (mới) — file `.mjs` thuần, không cần compile, không nằm trong `src/` nên không vào bản build
- `backend_api/package.json` — script `test:smoke`
- `.github/workflows/backend.yml` — thêm bước `npm run test:smoke`

## Implementation

### API Routes

Không sửa route. Smoke test gọi 5 request; chạy mất khoảng 2–3 giây, phần lớn là thời gian khởi động server.

### UI Components

Không có.

### DB / KV Changes

Không có (DB trong RAM, mất khi server tắt).

### Ràng buộc áp dụng

- **#5** smoke test bắt được asset thiếu trong `dist/`.
- **#17** ghim `GEMINI_API_KEY=''`, `GEMINI_BASE_URL=''`, `AUTH_MODE=mock`, `DATABASE_PATH=:memory:` — không gọi Gemini hay Google, không tạo file DB. CI không có secret nào.

## Definition of Done

- [ ] `npm run build && npm run test:smoke` → `Smoke test đạt: /health, đăng nhập giả lập, generate-plan, lịch sử.`
- [ ] Kiểm ngược: đổi `user: Relation<User>` thành `user: User` trong `plan-record.entity.ts`, build lại → smoke test thoát mã 1, log có `ReferenceError: Cannot access 'User' before initialization`; trả lại như cũ → đạt
- [ ] Sau khi push: run CI mới nhất của `Thien-Source` là `completed success` trên Node 24 và 26
- [x] All API routes complete within deployment timeout — không sửa route
- [x] Auth check at top of each protected handler — không sửa route

## Test Checklist

1. **@happy**: bản build lên được, 5 request đều đúng
2. **@auth**: bước lịch sử dùng JWT thật do server phát
3. **@timeout**: server không lên sau 20 giây → thất bại, không treo CI (job còn `timeout-minutes: 10`)
4. **@partial-fail**: server thoát sớm → báo ngay `Server thoát sớm (mã …)` kèm log, không chờ hết 20 giây
5. **@token**: không áp dụng
6. **@db**: migration chạy được trên bản build (bảng tồn tại, plan lưu và đọc lại được)

## Tasks

### Task 1 — Script

`backend_api/scripts/smoke-test.mjs`:

```js
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
```

`backend_api/package.json` — thêm vào `scripts`, ngay sau `test:e2e`:

```json
    "test:smoke": "node scripts/smoke-test.mjs"
```

```bash
cd backend_api
npm run build && npm run test:smoke
```

Mong đợi: `Smoke test đạt: /health, đăng nhập giả lập, generate-plan, lịch sử.`

### Task 2 — Kiểm ngược: smoke test phải bắt được lỗi import vòng

```bash
cp src/database/entities/plan-record.entity.ts /tmp/plan-record.entity.ts.bak
sed -i '' 's/  user: Relation<User>;.*/  user: User;/' src/database/entities/plan-record.entity.ts   # macOS; Linux: sed -i
npm test 2>&1 | grep 'Tests '            # vẫn xanh — đây là lý do cần smoke test
npm run build && npm run test:smoke; echo "exit=$?"   # thất bại, ReferenceError, exit=1
cp /tmp/plan-record.entity.ts.bak src/database/entities/plan-record.entity.ts
npm run build && npm run test:smoke      # đạt
git diff --stat src/database/entities/   # không còn thay đổi nào
```

### Task 3 — CI

`.github/workflows/backend.yml`, job `backend` — thêm một bước sau `npm run test:e2e`:

```yaml
      - run: npm ci
      - run: npm run build
      - run: npm test
      - run: npm run test:e2e
      - run: npm run test:smoke
```

`npm ci` trên Ubuntu tải bản dựng sẵn của `better-sqlite3` cho Node 24 và 26. Nếu không tải được, nó tự build từ mã nguồn (runner có sẵn Python và trình biên dịch C++), chỉ chậm hơn khoảng một phút. Nếu job vẫn đỏ vì driver này, đổi driver sang `sqljs` như brainstorm mục 4.1 đã dự phòng: entity giữ nguyên, nhưng migration phải được kiểm lại bằng `migrations.spec.ts`.

### Task 4 — Cổng kiểm tra F04 (sau khi push ở cuối giai đoạn)

```bash
curl -s 'https://api.github.com/repos/AlenJason/AI-Product-Development-End-to-End/actions/runs?branch=Thien-Source&per_page=1' \
  | python3 -c "import json,sys; r=json.load(sys.stdin)['workflow_runs'][0]; print(r['name'], r['status'], r['conclusion'], r['head_sha'][:7])"
```

Mong đợi: `Backend CI completed success <sha của commit vừa push>` (chờ khoảng 2–4 phút sau khi push).

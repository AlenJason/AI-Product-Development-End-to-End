import { readFileSync } from 'node:fs';
import request from 'supertest';
import { ADMIN_PAGE_JS } from '../src/admin/admin-page.js';
import { hashAdminPassword } from '../src/admin/admin-password.js';
import { vnDay } from '../src/stats/stats.service.js';
import { startFakeGemini, type FakeGemini } from './fake-gemini-server.js';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

// API và trang thống kê cho Admin (giai đoạn 10) — chỉ số đếm và nhật ký Gemini, không có dữ liệu cá nhân.
const SAMPLE_CONTENT: unknown = JSON.parse(readFileSync(new URL('../src/plan/data/sample-plan.json', import.meta.url), 'utf-8'));
const PASSWORD = 'mat-khau-quan-tri-123';
const SECRET = 'BENH-NEN-BI-MAT-123';
const PROFILE = {
  age: 22,
  gender: 'female',
  height_cm: 168,
  weight_kg: 62,
  activity_level: 'light',
  goal: 'cut',
  restrictions: { allergies: '', injuries: '', health_conditions: SECRET },
};

describe('Trang thống kê Admin (e2e)', () => {
  let testApp: TestApp;
  let fake: FakeGemini;
  let adminToken: string;
  const month = vnDay(Date.now()).slice(0, 7);
  const http = () => request(testApp.app.getHttpServer());
  const asAdmin = (path: string) => http().get(path).set('Authorization', `Bearer ${adminToken}`);

  beforeAll(async () => {
    fake = await startFakeGemini();
    testApp = await createTestApp({
      ADMIN_USERNAME: 'admin',
      ADMIN_PASSWORD_HASH: await hashAdminPassword(PASSWORD),
      GEMINI_API_KEY: 'test-key',
      GEMINI_BASE_URL: fake.url,
      GEMINI_TIMEOUT_MS: '200',
      GEMINI_FALLBACK_MODEL: 'gemini-3.6-flash',
    });
    const { access_token } = await loginMock(testApp, 'lan@vku.edu.vn');
    // Một plan Gemini (model chính quá tải → model dự phòng), một plan mẫu (cả 4 lần đều sai hợp đồng).
    fake.reply({ kind: 'error', status: 503, message: 'This model is currently experiencing high demand.' }, { kind: 'json', body: SAMPLE_CONTENT });
    await http().post('/api/v1/generate-plan').set('Authorization', `Bearer ${access_token}`).send(PROFILE).expect(200);
    fake.reply({ kind: 'json', body: { days: [] } });
    await http().post('/api/v1/generate-plan').send(PROFILE).expect(200);
    adminToken = (await http().post('/api/v1/admin/login').send({ username: 'admin', password: PASSWORD }).expect(200)).body.access_token;
  });

  afterAll(async () => {
    await testApp.close();
    await fake.close();
  });

  it('shows today: Gemini calls per model, Gemini settings, accounts and rate limits', async () => {
    const { body } = await asAdmin('/api/v1/admin/stats/overview').expect(200);
    expect(body).toEqual({
      today: vnDay(Date.now()),
      gemini: {
        configured: true,
        primary_model: 'gemini-3.5-flash',
        fallback_model: 'gemini-3.6-flash',
        per_call_timeout_ms: 200,
        total_timeout_ms: 40_000,
        daily_limit_per_model: 20,
      },
      gemini_today: [
        { model: 'gemini-3.5-flash', calls: 3, ok: 0 },
        { model: 'gemini-3.6-flash', calls: 3, ok: 1 },
      ],
      accounts: 1,
      saved_plans: 1,
      rate_limits: { plan: 'tắt', adjust: 'tắt', admin: 'tắt' },
    });
  });

  it('adds up each month, newest first, with Gemini outcomes per model', async () => {
    const { body } = await asAdmin('/api/v1/admin/stats/months').expect(200);
    expect(body).toHaveLength(1);
    expect(body[0].month).toBe(month);
    expect(body[0].usage).toMatchObject({
      'plan.gemini': { count: 1 },
      'plan.sample': { count: 1 },
      'plan.guest': { count: 1 },
      'plan.signed_in': { count: 1 },
      'admin.login.ok': { count: 1 },
    });
    expect(body[0].gemini.map(({ model, outcome, calls }: { model: string; outcome: string; calls: number }) => ({ model, outcome, calls }))).toEqual([
      { model: 'gemini-3.5-flash', outcome: 'invalid', calls: 2 },
      { model: 'gemini-3.5-flash', outcome: 'overloaded', calls: 1 },
      { model: 'gemini-3.6-flash', outcome: 'invalid', calls: 2 },
      { model: 'gemini-3.6-flash', outcome: 'ok', calls: 1 },
    ]);
  });

  it('lists the days of a month and the Gemini log, newest first, filterable by outcome', async () => {
    const detail = await asAdmin(`/api/v1/admin/stats/months/${month}`).expect(200);
    expect(detail.body.days.map((day: { day: string }) => day.day)).toEqual([vnDay(Date.now())]);

    const all = await asAdmin(`/api/v1/admin/stats/gemini-calls?month=${month}`).expect(200);
    expect(all.body).toMatchObject({ month, page: 1, page_size: 50, total: 6 });
    expect(all.body.calls[0]).toMatchObject({ task: 'plan', model: 'gemini-3.6-flash', attempt: 4, outcome: 'invalid' });
    const overloaded = await asAdmin(`/api/v1/admin/stats/gemini-calls?month=${month}&outcome=overloaded`).expect(200);
    expect(overloaded.body.calls).toEqual([
      expect.objectContaining({ model: 'gemini-3.5-flash', attempt: 1, http_status: 503, message: expect.stringContaining('high demand') }),
    ]);
    expect(JSON.stringify([all.body, detail.body])).not.toContain(SECRET);
  });

  it.each([
    '/api/v1/admin/stats/months/2026-13',
    '/api/v1/admin/stats/gemini-calls?month=2026-1',
    `/api/v1/admin/stats/gemini-calls?month=${month}&outcome=pwned`,
    `/api/v1/admin/stats/gemini-calls?month=${month}&page=0`,
  ])('rejects %s with 400', async (path) => {
    await asAdmin(path).expect(400);
  });

  it('opens the numbers only to the admin token', async () => {
    const userToken = (await loginMock(testApp, 'minh@vku.edu.vn')).access_token;
    await http().get('/api/v1/admin/stats/overview').expect(401);
    await http().get('/api/v1/admin/stats/months').set('Authorization', `Bearer ${userToken}`).expect(401);
  });

  it('serves the page at /admin with a strict content security policy', async () => {
    const page = await http().get('/admin').expect(200);
    expect(page.headers['content-type']).toContain('text/html');
    expect(page.headers['content-security-policy']).toContain("script-src 'self'");
    expect(page.headers['content-security-policy']).toContain("frame-ancestors 'none'");
    expect(page.headers['x-frame-options']).toBe('DENY');
    expect(page.headers['cache-control']).toBe('no-store');
    expect(page.text).toContain('<script src="/admin/app.js" defer></script>');
    expect((await http().get('/admin/app.js').expect(200)).headers['content-type']).toContain('text/javascript');
    expect((await http().get('/admin/app.css').expect(200)).headers['content-type']).toContain('text/css');
  });

  it('builds the page with textContent only — data from the server is never parsed as HTML', () => {
    expect(ADMIN_PAGE_JS).not.toMatch(/innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(/);
  });

  it('documents the admin API in Swagger but not the page', async () => {
    const { body } = await http().get('/docs-json').expect(200);
    expect(Object.keys(body.paths)).toEqual(expect.arrayContaining(['/api/v1/admin/login', '/api/v1/admin/stats/overview']));
    expect(Object.keys(body.paths).filter((path) => path.startsWith('/admin'))).toEqual([]);
  });
});

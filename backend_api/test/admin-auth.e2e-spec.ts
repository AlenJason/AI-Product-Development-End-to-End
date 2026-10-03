import request from 'supertest';
import { DataSource } from 'typeorm';
import { ADMIN_DISABLED, ADMIN_LOGIN_FAILED, ADMIN_SESSION_INVALID } from '../src/admin/admin-auth.service.js';
import { hashAdminPassword } from '../src/admin/admin-password.js';
import { UsageDaily } from '../src/stats/usage-daily.entity.js';
import { createFailingTestApp, createTestApp, loginMock, type TestApp } from './test-app.js';

// Đăng nhập trang thống kê bằng tài khoản Admin cấp sẵn (giai đoạn 10, quyết định Q1).
const PASSWORD = 'mat-khau-quan-tri-123';

describe('Đăng nhập Admin (e2e)', () => {
  let testApp: TestApp;
  let hash: string;
  const http = () => request(testApp.app.getHttpServer());
  const login = (username: string, password: string) => http().post('/api/v1/admin/login').send({ username, password });
  const adminApp = (env: Record<string, string> = {}) =>
    createTestApp({ ADMIN_USERNAME: 'admin', ADMIN_PASSWORD_HASH: hash, ...env });
  const usage = async () =>
    Object.fromEntries((await testApp.app.get(DataSource).getRepository(UsageDaily).find()).map((row) => [row.metric, row.count]));

  beforeAll(async () => {
    hash = await hashAdminPassword(PASSWORD);
  });

  afterEach(async () => {
    await testApp?.close();
  });

  it('signs in with the provisioned account and opens a session', async () => {
    testApp = await adminApp();
    const res = await login('admin', PASSWORD).expect(200);
    expect(res.body).toEqual({ access_token: expect.any(String), expires_in: 8 * 3600 });
    const session = await http().get('/api/v1/admin/session').set('Authorization', `Bearer ${res.body.access_token}`).expect(200);
    expect(session.body).toEqual({ username: 'admin' });
    expect(await usage()).toEqual({ 'admin.login.ok': 1 });
  });

  it('answers a wrong username and a wrong password with the same sentence, and counts both', async () => {
    testApp = await adminApp();
    const wrongPassword = await login('admin', 'mat-khau-sai-12345').expect(401);
    const wrongUser = await login('root', PASSWORD).expect(401);
    expect(wrongPassword.body.message).toBe(ADMIN_LOGIN_FAILED);
    expect(wrongUser.body.message).toBe(ADMIN_LOGIN_FAILED);
    expect(await usage()).toEqual({ 'admin.login.failed': 2 });
  });

  it('stops password guessing per IP (RATE_LIMIT_ADMIN) — even the right password has to wait', async () => {
    testApp = await adminApp({ RATE_LIMIT_ADMIN: '2/15m' });
    await login('admin', 'sai-lan-1-aaaaaa').expect(401);
    await login('admin', 'sai-lan-2-aaaaaa').expect(401);
    const blocked = await login('admin', PASSWORD).expect(429);
    expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(890);
    expect(await usage()).toMatchObject({ 'admin.login.failed': 2, 'rate_limited.admin': 1 });
  });

  it('keeps admin and user tokens apart: neither opens the other side (401, never 500)', async () => {
    testApp = await adminApp();
    const adminToken = (await login('admin', PASSWORD).expect(200)).body.access_token as string;
    const userToken = (await loginMock(testApp, 'lan@vku.edu.vn')).access_token;
    const userSide = await http().get('/api/v1/plans/history').set('Authorization', `Bearer ${adminToken}`).expect(401);
    expect(userSide.body.message).not.toContain('admin');
    const adminSide = await http().get('/api/v1/admin/session').set('Authorization', `Bearer ${userToken}`).expect(401);
    expect(adminSide.body.message).toBe(ADMIN_SESSION_INVALID);
    await http().get('/api/v1/admin/session').expect(401);
  });

  it('ends every admin session when the password changes', async () => {
    testApp = await adminApp();
    const oldToken = (await login('admin', PASSWORD).expect(200)).body.access_token as string;
    await testApp.close();
    hash = await hashAdminPassword('mat-khau-moi-456789');
    testApp = await adminApp();
    await http().get('/api/v1/admin/session').set('Authorization', `Bearer ${oldToken}`).expect(401);
    hash = await hashAdminPassword(PASSWORD);
  });

  it('ends every admin session when the admin username changes', async () => {
    testApp = await adminApp();
    const oldToken = (await login('admin', PASSWORD).expect(200)).body.access_token as string;
    await testApp.close();
    testApp = await adminApp({ ADMIN_USERNAME: 'quantri' });
    await http().get('/api/v1/admin/session').set('Authorization', `Bearer ${oldToken}`).expect(401);
  });

  it('is off (404) when no admin account is configured', async () => {
    testApp = await createTestApp();
    expect((await login('admin', PASSWORD).expect(404)).body.message).toBe(ADMIN_DISABLED);
    await http().get('/api/v1/admin/session').set('Authorization', 'Bearer x').expect(404);
  });

  it('rejects an oversized password before running scrypt', async () => {
    testApp = await adminApp();
    await login('admin', 'a'.repeat(201)).expect(400);
  });

  it('refuses to start with half an admin account', async () => {
    await expect(createFailingTestApp({ ADMIN_USERNAME: 'admin' })).rejects.toThrow(/ADMIN_PASSWORD_HASH/);
  });
});

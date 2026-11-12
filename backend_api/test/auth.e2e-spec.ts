import request from 'supertest';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

describe('Đăng nhập & tài khoản (e2e, AUTH_MODE=mock, DB trong RAM)', () => {
  let testApp: TestApp;
  const http = () => request(testApp.app.getHttpServer());

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('logs in with a mock token and returns the same account next time', async () => {
    const first = await loginMock(testApp, 'an@vku.edu.vn');
    expect(first.user).toEqual({ id: expect.stringMatching(UUID), email: 'an@vku.edu.vn', name: 'an' });
    expect(first.access_token.split('.')).toHaveLength(3);
    const second = await loginMock(testApp, 'AN@vku.edu.vn');
    expect(second.user.id).toBe(first.user.id);
  });

  it.each([
    [400, 'without id_token', {}],
    [400, 'with a non-string id_token', { id_token: 123 }],
    [401, 'with a token that is not "mock:<email>"', { id_token: 'an@vku.edu.vn' }],
  ])('answers %i to a login %s', async (status, _label, payload) => {
    await http().post('/api/v1/auth/google').send(payload).expect(status);
  });

  it('deletes the account; the old token stops working and the next login is a new account', async () => {
    const { access_token, user } = await loginMock(testApp, 'xoa@vku.edu.vn');
    await http().delete('/api/v1/me').set('Authorization', `Bearer ${access_token}`).expect(204);
    await http().delete('/api/v1/me').set('Authorization', `Bearer ${access_token}`).expect(401);
    const again = await loginMock(testApp, 'xoa@vku.edu.vn');
    expect(again.user.id).not.toBe(user.id);
  });

  it.each([
    ['no header', undefined],
    ['a malformed header', 'Token abc'],
    ['a token that is not a JWT', 'Bearer not-a-jwt'],
  ])('refuses to delete an account with %s', async (_label, header) => {
    const req = http().delete('/api/v1/me');
    if (header) req.set('Authorization', header);
    await req.expect(401);
  });

  it('documents login and account deletion in Swagger with bearer auth', async () => {
    const { body } = await http().get('/docs-json').expect(200);
    expect(Object.keys(body.paths)).toEqual(
      expect.arrayContaining([
        '/api/v1/auth/google',
        '/api/v1/auth/register',
        '/api/v1/auth/login',
        '/api/v1/auth/change-password',
        '/api/v1/me',
      ]),
    );
    expect(body.components.securitySchemes).toHaveProperty('bearer');
  });

  it('registers, logs in with password, rejects wrong password, and changes password', async () => {
    const reg = await http()
      .post('/api/v1/auth/register')
      .send({ email: 'Minh@VKU.edu.vn', name: 'Công Minh', password: 'secret123' })
      .expect(200);
    expect(reg.body.user).toEqual({
      id: expect.stringMatching(UUID),
      email: 'minh@vku.edu.vn',
      name: 'Công Minh',
    });

    await http()
      .post('/api/v1/auth/register')
      .send({ email: 'minh@vku.edu.vn', name: 'Trùng', password: 'secret123' })
      .expect(409);

    await http()
      .post('/api/v1/auth/login')
      .send({ email: 'minh@vku.edu.vn', password: 'wrong' })
      .expect(401);

    const logged = await http()
      .post('/api/v1/auth/login')
      .send({ email: 'minh@vku.edu.vn', password: 'secret123' })
      .expect(200);
    expect(logged.body.user.id).toBe(reg.body.user.id);

    await http()
      .post('/api/v1/auth/change-password')
      .set('Authorization', `Bearer ${logged.body.access_token}`)
      .send({ current_password: 'wrong', new_password: 'newpassword99' })
      .expect(401);

    await http()
      .post('/api/v1/auth/change-password')
      .set('Authorization', `Bearer ${logged.body.access_token}`)
      .send({ current_password: 'secret123', new_password: 'newpassword99' })
      .expect(200);

    await http()
      .post('/api/v1/auth/login')
      .send({ email: 'minh@vku.edu.vn', password: 'secret123' })
      .expect(401);

    await http()
      .post('/api/v1/auth/login')
      .send({ email: 'minh@vku.edu.vn', password: 'newpassword99' })
      .expect(200);
  });
});

describe('Cấu hình đăng nhập lúc khởi động (e2e)', () => {
  it('refuses to start with AUTH_MODE=mock in production', async () => {
    await expect(createTestApp({ NODE_ENV: 'production' })).rejects.toThrow(/ALLOW_MOCK_AUTH/);
  });

  it('starts in production with mock auth only when ALLOW_MOCK_AUTH=true', async () => {
    const testApp = await createTestApp({ NODE_ENV: 'production', ALLOW_MOCK_AUTH: 'true' });
    try {
      const { body } = await request(testApp.app.getHttpServer()).get('/health').expect(200);
      expect(body.auth_mode).toBe('mock');
    } finally {
      await testApp.close();
    }
  });

  it('refuses to start in google mode without GOOGLE_CLIENT_ID', async () => {
    await expect(createTestApp({ AUTH_MODE: 'google', JWT_SECRET: 'x'.repeat(32) })).rejects.toThrow(
      /GOOGLE_CLIENT_ID/,
    );
  });
});

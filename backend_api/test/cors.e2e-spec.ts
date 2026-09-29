import request from 'supertest';
import { createTestApp, type TestApp } from './test-app.js';

// Trình duyệt gửi preflight OPTIONS trước mọi POST JSON hay request có Authorization từ origin khác (Flutter web).
const preflight = (testApp: TestApp, origin: string) =>
  request(testApp.app.getHttpServer())
    .options('/api/v1/generate-plan')
    .set('Origin', origin)
    .set('Access-Control-Request-Method', 'POST')
    .set('Access-Control-Request-Headers', 'content-type,authorization');

describe('CORS cho Flutter web (e2e)', () => {
  describe('khi phát triển (CORS_ORIGINS để trống)', () => {
    let testApp: TestApp;

    beforeAll(async () => {
      testApp = await createTestApp();
    });

    afterAll(async () => {
      await testApp.close();
    });

    it('answers the preflight from Flutter web on localhost', async () => {
      const res = await preflight(testApp, 'http://localhost:5000').expect(204);
      expect(res.headers['access-control-allow-origin']).toBe('http://localhost:5000');
      expect(res.headers['access-control-allow-headers']).toContain('Authorization');
      expect(res.headers['access-control-allow-methods']).toContain('POST');
    });

    it('does not allow another origin', async () => {
      const res = await preflight(testApp, 'https://evil.example');
      expect(res.headers['access-control-allow-origin']).toBeUndefined();
    });

    it('does not change requests without Origin (mobile apps, curl)', async () => {
      const res = await request(testApp.app.getHttpServer()).get('/health').expect(200);
      expect(res.headers['access-control-allow-origin']).toBeUndefined();
    });
  });

  it('only allows the configured origins', async () => {
    const testApp = await createTestApp({ CORS_ORIGINS: 'https://smartfit.example' });
    try {
      expect((await preflight(testApp, 'https://smartfit.example').expect(204)).headers['access-control-allow-origin']).toBe(
        'https://smartfit.example',
      );
      expect((await preflight(testApp, 'http://localhost:5000')).headers['access-control-allow-origin']).toBeUndefined();
    } finally {
      await testApp.close();
    }
  });

  it('is off in production when no origin is configured', async () => {
    const testApp = await createTestApp({ NODE_ENV: 'production', ALLOW_MOCK_AUTH: 'true' });
    try {
      expect((await preflight(testApp, 'http://localhost:5000')).headers['access-control-allow-origin']).toBeUndefined();
    } finally {
      await testApp.close();
    }
  });

  it('refuses to start with an invalid CORS_ORIGINS', async () => {
    await expect(createTestApp({ CORS_ORIGINS: '*' })).rejects.toThrow(/CORS_ORIGINS/);
  });
});

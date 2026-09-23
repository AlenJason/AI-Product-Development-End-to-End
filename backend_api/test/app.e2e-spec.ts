import request from 'supertest';
import { createTestApp, type TestApp } from './test-app.js';

describe('AppController (e2e)', () => {
  let testApp: TestApp;

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('/health (GET)', async () => {
    const res = await request(testApp.app.getHttpServer()).get('/health').expect(200);
    expect(res.body).toEqual({ status: 'ok', gemini: 'fallback', auth_mode: 'mock' });
  });
});

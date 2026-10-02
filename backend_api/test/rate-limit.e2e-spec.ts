import request from 'supertest';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

// Giới hạn tần suất (PLAN 9.7, quyết định Q2 giai đoạn 9): khách theo IP, đã đăng nhập theo tài khoản.
const PROFILE = {
  age: 22,
  gender: 'female',
  height_cm: 168,
  weight_kg: 62,
  activity_level: 'light',
  goal: 'cut',
  restrictions: { allergies: '', injuries: '', health_conditions: '' },
};

describe('Giới hạn tần suất (e2e)', () => {
  let testApp: TestApp;
  const http = () => request(testApp.app.getHttpServer());
  const generate = (headers: Record<string, string> = {}) => {
    const req = http().post('/api/v1/generate-plan');
    for (const [name, value] of Object.entries(headers)) req.set(name, value);
    return req.send(PROFILE);
  };
  const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

  afterEach(async () => {
    await testApp?.close();
  });

  it('khách quá số lần tạo plan → 429, câu tiếng Việt, Retry-After là số giây chờ', async () => {
    testApp = await createTestApp({ RATE_LIMIT_PLAN: '2/10m' });
    await generate().expect(200);
    await generate().expect(200);
    const res = await generate().expect(429);
    expect(res.body).toEqual({
      statusCode: 429,
      error: 'Too Many Requests',
      message: 'Bạn thao tác quá nhanh. Vui lòng thử lại sau 10 phút.',
    });
    expect(Number(res.headers['retry-after'])).toBeGreaterThan(590);
  });

  it('đã đăng nhập → đếm theo tài khoản: cùng IP với khách đã hết lượt vẫn tạo được; mỗi tài khoản riêng', async () => {
    testApp = await createTestApp({ RATE_LIMIT_PLAN: '1/10m' });
    await generate().expect(200);
    await generate().expect(429);

    const lan = await loginMock(testApp, 'lan@vku.edu.vn');
    const minh = await loginMock(testApp, 'minh@vku.edu.vn');
    await generate(bearer(lan.access_token)).expect(200);
    await generate(bearer(lan.access_token)).expect(429);
    await generate(bearer(minh.access_token)).expect(200);
  });

  it('token sai → 401 trước khi đếm, không tốn lượt', async () => {
    testApp = await createTestApp({ RATE_LIMIT_PLAN: '1/10m' });
    await generate(bearer('sai')).expect(401);
    await generate(bearer('sai')).expect(401);
    await generate().expect(200);
  });

  it('đổi món, đổi bài, feedback dùng chung một hạn mức, tách khỏi hạn mức tạo plan', async () => {
    testApp = await createTestApp({ RATE_LIMIT_PLAN: '1/10m', RATE_LIMIT_ADJUST: '2/10m' });
    const plan = (await generate().expect(200)).body;
    await http().post('/api/v1/meals/swap').send({ profile: PROFILE, plan, meal_id: 'm1_1' }).expect(200);
    await http().post('/api/v1/exercises/swap').send({ profile: PROFILE, plan, exercise_id: 'e1_1' }).expect(200);
    const res = await http()
      .post('/api/v1/feedback')
      .send({ profile: PROFILE, plan, day_number: 1, intensity: 'moderate', body_states: ['normal'], eating: 'on_plan' })
      .expect(429);
    expect(res.body.message).toMatch(/^Bạn thao tác quá nhanh/);
  });

  it('TRUST_PROXY_HOPS=1 (Vercel): khách đếm theo IP trong X-Forwarded-For', async () => {
    testApp = await createTestApp({ RATE_LIMIT_PLAN: '1/10m', TRUST_PROXY_HOPS: '1' });
    await generate({ 'X-Forwarded-For': '203.0.113.7' }).expect(200);
    await generate({ 'X-Forwarded-For': '203.0.113.7' }).expect(429);
    await generate({ 'X-Forwarded-For': '198.51.100.9' }).expect(200);
  });

  it('IPv6: cùng mạng /64 là một khách (đổi địa chỉ không lấy thêm lượt)', async () => {
    testApp = await createTestApp({ RATE_LIMIT_PLAN: '1/10m', TRUST_PROXY_HOPS: '1' });
    await generate({ 'X-Forwarded-For': '2001:db8:85a3:12::1' }).expect(200);
    await generate({ 'X-Forwarded-For': '2001:db8:85a3:12:abcd::2' }).expect(429);
    await generate({ 'X-Forwarded-For': '2001:db8:85a3:13::1' }).expect(200);
  });

  it('không tin proxy (mặc định): tự ghi X-Forwarded-For không đổi được IP', async () => {
    testApp = await createTestApp({ RATE_LIMIT_PLAN: '1/10m' });
    await generate({ 'X-Forwarded-For': '203.0.113.7' }).expect(200);
    await generate({ 'X-Forwarded-For': '198.51.100.9' }).expect(429);
  });

  it('lịch sử, đăng nhập, /health không bị giới hạn; Swagger ghi mã 429', async () => {
    testApp = await createTestApp({ RATE_LIMIT_PLAN: '1/10m', RATE_LIMIT_ADJUST: '1/10m' });
    const { access_token } = await loginMock(testApp, 'lan@vku.edu.vn');
    for (let i = 0; i < 3; i++) {
      await http().get('/health').expect(200);
      await loginMock(testApp, 'lan@vku.edu.vn');
      await http().get('/api/v1/plans/history').set(bearer(access_token)).expect(200);
    }
    const { body } = await http().get('/docs-json').expect(200);
    expect(body.paths['/api/v1/generate-plan'].post.responses['429']).toBeDefined();
    expect(body.paths['/api/v1/meals/swap'].post.responses['429']).toBeDefined();
  });
});

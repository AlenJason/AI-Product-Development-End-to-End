import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import request from 'supertest';
import { RandomSource } from '../src/plan/adjust/random-source.js';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

// Fixture hợp đồng cho app Flutter (frontend_app/test/fixtures/): JSON thật backend trả qua HTTP, đã thay các giá trị
// đổi theo mỗi lần chạy (UUID, token, thời điểm) bằng giá trị cố định. Test này đỏ khi hợp đồng đổi mà fixture chưa
// xuất lại — chạy `npm run fixtures:update` rồi commit cả fixture lẫn phần sửa model Dart.
const FIXTURES_DIR = new URL('../../frontend_app/test/fixtures/', import.meta.url);
const UPDATE = process.env.UPDATE_FIXTURES === '1';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const FIXED_TIME = '2026-09-24T00:00:00.000Z';
const FIXED_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fixture.signature';

const PROFILE = {
  age: 22,
  gender: 'female',
  height_cm: 168,
  weight_kg: 62,
  activity_level: 'light',
  goal: 'cut',
  restrictions: { allergies: 'Hải sản', injuries: 'Đau gối', health_conditions: 'Tiểu đường' },
};

describe('Fixture hợp đồng cho Flutter (e2e)', () => {
  let testApp: TestApp;
  const fixedIds = new Map<string, string>();
  const http = () => request(testApp.app.getHttpServer());

  // UUID giống nhau ở mọi file (plan_id trong lịch sử = plan_id lúc tạo) → cùng một giá trị cố định.
  const normalize = (value: unknown, key?: string): unknown => {
    if (Array.isArray(value)) return value.map((item) => normalize(item));
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, normalize(v, k)]));
    }
    if (typeof value !== 'string') return value;
    if (key === 'access_token') return FIXED_TOKEN;
    if (key === 'created_at') return FIXED_TIME;
    if (UUID.test(value)) {
      if (!fixedIds.has(value)) fixedIds.set(value, `00000000-0000-4000-8000-${String(fixedIds.size + 1).padStart(12, '0')}`);
      return fixedIds.get(value);
    }
    return value;
  };

  const check = (name: string, body: unknown) => {
    const file = new URL(`${name}.json`, FIXTURES_DIR);
    const actual = normalize(body);
    if (UPDATE) {
      mkdirSync(FIXTURES_DIR, { recursive: true });
      writeFileSync(file, `${JSON.stringify(actual, null, 2)}\n`);
      return;
    }
    expect(actual, `${name}.json đã cũ — chạy npm run fixtures:update`).toEqual(JSON.parse(readFileSync(file, 'utf-8')));
  };

  beforeAll(async () => {
    testApp = await createTestApp({}, (builder) => builder.overrideProvider(RandomSource).useValue({ next: () => 0 }));
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('matches every committed fixture', async () => {
    check('profile', PROFILE);
    check('health', (await http().get('/health').expect(200)).body);

    const login = await loginMock(testApp, 'sv@vku.edu.vn');
    check('auth_login', login);
    const auth = `Bearer ${login.access_token}`;

    const plan = (await http().post('/api/v1/generate-plan').set('Authorization', auth).send(PROFILE).expect(200)).body;
    check('generate_plan', plan);
    check('history', (await http().get('/api/v1/plans/history').set('Authorization', auth).expect(200)).body);
    check('meals_swap', (await http().post('/api/v1/meals/swap').send({ profile: PROFILE, plan, meal_id: 'm1_2' }).expect(200)).body);
    check('exercises_swap', (await http().post('/api/v1/exercises/swap').send({ profile: PROFILE, plan, exercise_id: 'e1_2' }).expect(200)).body);
    const feedback = { profile: PROFILE, plan, day_number: 1, eating: 'on_plan' };
    check('feedback', (await http().post('/api/v1/feedback').send({ ...feedback, intensity: 'hard', body_states: ['sore'] }).expect(200)).body);
    check('feedback_danger', (await http().post('/api/v1/feedback').send({ ...feedback, intensity: 'easy', body_states: ['danger_sign'] }).expect(200)).body);

    check('error_400', (await http().post('/api/v1/generate-plan').send({ ...PROFILE, age: 'hai mươi' }).expect(400)).body);
    check('error_401', (await http().get('/api/v1/plans/history').expect(401)).body);
    check('error_404', (await http().get('/api/v1/plans/history/00000000-0000-4000-8000-00000000abcd').set('Authorization', auth).expect(404)).body);
    check('error_409', (await http().post('/api/v1/meals/swap').send({ profile: { ...PROFILE, goal: 'bulk' }, plan, meal_id: 'm1_1' }).expect(409)).body);
    check('error_422', (await http().post('/api/v1/exercises/swap').send({ profile: PROFILE, plan, exercise_id: 'e3_2' }).expect(422)).body);
  });
});

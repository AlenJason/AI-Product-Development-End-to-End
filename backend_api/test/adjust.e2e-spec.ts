import { JwtService } from '@nestjs/jwt';
import request from 'supertest';
import { DataSource } from 'typeorm';
import { createTestApp, loginMock, type TestApp } from './test-app.js';
import { startFakeGemini, type FakeGemini } from './fake-gemini-server.js';
import { PlanRecord } from '../src/database/entities/plan-record.entity.js';
import type { MealPlanResponseDto } from '../src/plan/dto/meal-plan-response.dto.js';
import { WARNINGS } from '../src/plan/plan-warnings.js';

const PROFILE = {
  gender: 'female',
  age: 30,
  height_cm: 165,
  weight_kg: 60,
  activity_level: 'light',
  goal: 'maintain',
  restrictions: {
    dietary_preference: '',
    allergies: 'Tôm',
    health_conditions: '',
  },
};

describe('Đổi món (e2e, chế độ giả lập)', () => {
  let testApp: TestApp;
  let fake: FakeGemini;
  let samplePlan: MealPlanResponseDto;
  let db: DataSource;

  beforeAll(async () => {
    fake = await startFakeGemini();
    testApp = await createTestApp({ GEMINI_API_KEY: 'test-key', GEMINI_BASE_URL: fake.url, GEMINI_TIMEOUT_MS: '200' });
    db = testApp.app.get(DataSource);
    const res = await request(testApp.app.getHttpServer()).post('/api/v1/generate-plan').send(PROFILE).expect(200);
    samplePlan = res.body;
  });

  afterAll(async () => {
    await testApp.close();
    await fake.close();
  });

  const post = (url: string, payload: object, token?: string) => {
    let req = request(testApp.app.getHttpServer()).post(url);
    if (token) req = req.set('Authorization', `Bearer ${token}`);
    return req.send(payload);
  };

  describe('POST /api/v1/meals/swap', () => {
    const payload = () => ({ profile: PROFILE, plan: samplePlan, meal_id: 'm1_2' });

    it('returns 401 if token is invalid', async () => {
      await post('/api/v1/meals/swap', payload(), 'invalid-token').expect(401);
    });

    it('returns 401 if token is expired', async () => {
      const { user } = await loginMock(testApp, 'expired@example.com');
      const token = await testApp.app.get(JwtService).signAsync({ sub: user.id }, { expiresIn: -60 });
      await post('/api/v1/meals/swap', payload(), token).expect(401);
    });

    it('returns 400 if plan or profile is missing', async () => {
      await post('/api/v1/meals/swap', { plan: samplePlan, meal_id: 'm1_2' }).expect(400);
      await post('/api/v1/meals/swap', { profile: PROFILE, meal_id: 'm1_2' }).expect(400);
      await post('/api/v1/meals/swap', { ...payload(), meal_id: 'bad-id' }).expect(400);
    });

    it('returns 409 if plan was generated for a different profile (target calories differ)', async () => {
      const differentProfile = { ...PROFILE, age: 40 }; // Changes target calories
      await post('/api/v1/meals/swap', { profile: differentProfile, plan: samplePlan, meal_id: 'm1_2' }).expect(409);
    });

    it('swaps meal successfully and does not save to DB for guest', async () => {
      fake.reply({ kind: 'json', body: { meal_type: 'lunch', name: 'Com chien', portion: '1', calories: 600, protein_g: 40, carbs_g: 60, fat_g: 22, ingredients: [] } });
      const res = await post('/api/v1/meals/swap', payload()).expect(200);
      expect(res.body.plan.days[0].meals[1].name).not.toBe(samplePlan.days[0].meals[1].name);

      const count = await db.getRepository(PlanRecord).count({ where: { id: samplePlan.plan_id } });
      expect(count).toBe(0);
    });

    it('swaps meal successfully and saves to DB for logged in user', async () => {
      const { access_token: token } = await loginMock(testApp, 'test@example.com');
      // Create a plan first to have it in the DB under this user
      const initRes = await post('/api/v1/generate-plan', PROFILE, token).expect(200);
      const userPlan = initRes.body;

      fake.reply({ kind: 'json', body: { meal_type: 'lunch', name: 'Pho bo', portion: '1', calories: 600, protein_g: 40, carbs_g: 60, fat_g: 22, ingredients: [] } });
      const swapRes = await post('/api/v1/meals/swap', { profile: PROFILE, plan: userPlan, meal_id: 'm1_2' }, token).expect(200);
      expect(swapRes.body.plan.days[0].meals[1].name).not.toBe(userPlan.days[0].meals[1].name);

      const record = await db.getRepository(PlanRecord).findOneBy({ id: userPlan.plan_id });
      expect(record).not.toBeNull();
      expect(record!.plan_json.days[0].meals[1].name).not.toBe(userPlan.days[0].meals[1].name);
    });

    it('does not update another user’s saved plan', async () => {
      const owner = await loginMock(testApp, 'owner@example.com');
      const other = await loginMock(testApp, 'other@example.com');
      const userPlan = (await post('/api/v1/generate-plan', PROFILE, owner.access_token).expect(200)).body;
      fake.reply({ kind: 'json', body: { meal_type: 'lunch', name: 'Com chien', portion: '1', calories: 600, protein_g: 40, carbs_g: 60, fat_g: 22, ingredients: [] } });

      await post('/api/v1/meals/swap', { ...payload(), plan: userPlan }, other.access_token).expect(200);
      const record = await db.getRepository(PlanRecord).findOneBy({ id: userPlan.plan_id });
      expect(record?.user_id).toBe(owner.user.id);
      expect(record?.plan_json.days[0].meals[1].name).toBe(userPlan.days[0].meals[1].name);
    });

    it('returns the swapped plan with a warning when history update fails', async () => {
      const { access_token: token } = await loginMock(testApp, 'db-failure@example.com');
      const userPlan = (await post('/api/v1/generate-plan', PROFILE, token).expect(200)).body;
      await db.query('DROP TABLE plan_records');
      fake.reply({ kind: 'json', body: { meal_type: 'lunch', name: 'Com chien', portion: '1', calories: 600, protein_g: 40, carbs_g: 60, fat_g: 22, ingredients: [] } });

      const response = await post('/api/v1/meals/swap', { ...payload(), plan: userPlan }, token).expect(200);
      expect(response.body.plan.warnings).toContain(WARNINGS.historyNotSaved);
      expect(response.body.plan.days[0].meals[1].name).not.toBe(userPlan.days[0].meals[1].name);
    });
  });
});

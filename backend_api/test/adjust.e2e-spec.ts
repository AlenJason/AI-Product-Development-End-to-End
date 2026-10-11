import { JwtService } from '@nestjs/jwt';
import request from 'supertest';
import { DataSource } from 'typeorm';
import { createTestApp, loginMock, type TestApp } from './test-app.js';
import { startFakeGemini, type FakeGemini } from './fake-gemini-server.js';
import { PlanRecord } from '../src/database/entities/plan-record.entity.js';
import { HistoryService } from '../src/history/history.service.js';
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

  describe('POST /api/v1/exercises/swap', () => {
    const payload = (plan = samplePlan, profile = PROFILE, exerciseId = 'e1_2') => ({
      profile,
      plan,
      exercise_id: exerciseId,
    });
    const lighterSquat = {
      name: 'Squat nửa biên độ dựa ghế',
      sets: 2,
      reps_or_duration: '10 lần',
      muscle_group: 'legs',
      tags: [],
    };

    it('rejects invalid and expired tokens', async () => {
      await post('/api/v1/exercises/swap', payload(), 'invalid-token').expect(401);
      const { user } = await loginMock(testApp, 'expired-exercise@example.com');
      const token = await testApp.app.get(JwtService).signAsync({ sub: user.id }, { expiresIn: -60 });
      await post('/api/v1/exercises/swap', payload(), token).expect(401);
    });

    it('validates the profile, plan and exercise id', async () => {
      await post('/api/v1/exercises/swap', { plan: samplePlan, exercise_id: 'e1_2' }).expect(400);
      await post('/api/v1/exercises/swap', { profile: PROFILE, exercise_id: 'e1_2' }).expect(400);
      await post('/api/v1/exercises/swap', payload(samplePlan, PROFILE, 'bad-id')).expect(400);
      await post('/api/v1/exercises/swap', payload(samplePlan, PROFILE, 'e1_8')).expect(400);
    });

    it('swaps for a guest without writing history', async () => {
      fake.reply({ kind: 'json', body: lighterSquat });
      const response = await post('/api/v1/exercises/swap', payload()).expect(200);
      expect(response.body.plan.days[0].workout.exercises[1].name).toBe(lighterSquat.name);
      expect(await db.getRepository(PlanRecord).count({ where: { id: samplePlan.plan_id } })).toBe(0);
    });

    it('uses the pool after AI errors and excludes movements that load a declared injury', async () => {
      const injuryProfile = {
        ...PROFILE,
        restrictions: { ...PROFILE.restrictions, injuries: 'đau gối' },
      };
      fake.reply({ kind: 'error', status: 500, message: 'temporary upstream error' });
      const response = await post(
        '/api/v1/exercises/swap',
        payload(samplePlan, injuryProfile, 'e1_1'),
      ).expect(200);

      expect(fake.paths).toHaveLength(2);
      expect(response.body.plan.days[0].workout.exercises[0].tags).not.toContain('jumping');
    });

    it('returns 422 when no lighter exercise is available', async () => {
      fake.reply({ kind: 'error', status: 500, message: 'temporary upstream error' });
      await post('/api/v1/exercises/swap', payload(samplePlan, PROFILE, 'e3_2')).expect(422);
    });

    it('updates the saved plan only for its owner', async () => {
      const owner = await loginMock(testApp, 'exercise-owner@example.com');
      const other = await loginMock(testApp, 'exercise-other@example.com');
      const userPlan = (await post('/api/v1/generate-plan', PROFILE, owner.access_token).expect(200)).body;
      fake.reply({ kind: 'json', body: lighterSquat });

      await post('/api/v1/exercises/swap', payload(userPlan), owner.access_token).expect(200);
      const ownerRecord = await db.getRepository(PlanRecord).findOneBy({ id: userPlan.plan_id });
      expect(ownerRecord?.user_id).toBe(owner.user.id);
      expect(ownerRecord?.plan_json.days[0].workout.exercises[1].name).toBe(lighterSquat.name);

      fake.reply({ kind: 'json', body: { ...lighterSquat, name: 'Squat nhẹ dựa ghế' } });
      await post('/api/v1/exercises/swap', payload(userPlan), other.access_token).expect(200);
      const unchanged = await db.getRepository(PlanRecord).findOneBy({ id: userPlan.plan_id });
      expect(unchanged?.user_id).toBe(owner.user.id);
      expect(unchanged?.plan_json.days[0].workout.exercises[1].name).toBe(lighterSquat.name);
    });

    it('returns the plan with a warning when history update fails', async () => {
      const { access_token: token } = await loginMock(testApp, 'exercise-db-failure@example.com');
      const userPlan = (await post('/api/v1/generate-plan', PROFILE, token).expect(200)).body;
      const update = vi.spyOn(testApp.app.get(HistoryService), 'update').mockResolvedValue(false);
      try {
        fake.reply({ kind: 'json', body: lighterSquat });
        const response = await post('/api/v1/exercises/swap', payload(userPlan), token).expect(200);
        expect(response.body.plan.warnings).toContain(WARNINGS.historyNotSaved);
      } finally {
        update.mockRestore();
      }
    });
  });

  describe('POST /api/v1/feedback', () => {
    const payload = (plan = samplePlan, overrides: Record<string, unknown> = {}) => ({
      profile: PROFILE,
      plan,
      day_number: 1,
      intensity: 'hard',
      body_states: ['sore'],
      eating: 'on_plan',
      ...overrides,
    });

    it('validates feedback fields and the supplied plan', async () => {
      await post('/api/v1/feedback', { profile: PROFILE, day_number: 1 }).expect(400);
      await post('/api/v1/feedback', payload(samplePlan, { day_number: 4 })).expect(400);
      await post('/api/v1/feedback', payload(samplePlan, { body_states: [] })).expect(400);
      await post('/api/v1/feedback', payload(samplePlan, { intensity: 'unknown' })).expect(400);
      await post('/api/v1/feedback', payload(samplePlan, { plan: { days: [] } })).expect(400);
      await post('/api/v1/feedback', payload(samplePlan, { profile: { ...PROFILE, age: 40 } })).expect(409);
    });

    it('adjusts next-day workout for a guest without saving history', async () => {
      const response = await post('/api/v1/feedback', payload()).expect(200);
      expect(response.body.safety_warning).toBeNull();
      expect(response.body.plan.plan_id).toBe(samplePlan.plan_id);
      expect(response.body.plan.days[1].workout.duration_minutes).toBeLessThan(samplePlan.days[1].workout.duration_minutes);
      expect(await db.getRepository(PlanRecord).count({ where: { id: samplePlan.plan_id } })).toBe(0);
    });

    it('returns safety warning and rest on danger signs without calling Gemini', async () => {
      fake.reply({ kind: 'json', body: { meals: [] } });
      const response = await post(
        '/api/v1/feedback',
        payload(samplePlan, { body_states: ['danger_sign'], eating: 'over' }),
      ).expect(200);
      expect(response.body.safety_warning.message).toContain('115');
      expect(response.body.plan.days[1].workout.title).toContain('Nghỉ ngơi');
      expect(response.body.plan.days[1].meals).toEqual(samplePlan.days[1].meals);
      expect(fake.paths).toHaveLength(0);
    });

    it('rebalances meals when Gemini succeeds and safely falls back after AI failure', async () => {
      const rebalanced = {
        meals: [
          { meal_type: 'breakfast', name: 'Cháo yến mạch táo', portion: '1 bát', calories: 400, protein_g: 25, carbs_g: 50, fat_g: 11.11, ingredients: [{ name: 'Yến mạch', amount: 50, unit: 'g', category: 'pantry' }] },
          { meal_type: 'lunch', name: 'Cơm gạo lứt, gà hấp gừng', portion: '1 chén', calories: 600, protein_g: 37.5, carbs_g: 75, fat_g: 16.67, ingredients: [{ name: 'Gạo lứt', amount: 90, unit: 'g', category: 'pantry' }] },
          { meal_type: 'dinner', name: 'Canh rau củ đậu phụ non', portion: '1 bát', calories: 600, protein_g: 37.5, carbs_g: 75, fat_g: 16.67, ingredients: [{ name: 'Đậu phụ non', amount: 150, unit: 'g', category: 'protein' }] },
        ],
      };
      fake.reply({ kind: 'json', body: rebalanced });
      const success = await post('/api/v1/feedback', payload(samplePlan, { eating: 'over' })).expect(200);
      expect(success.body.plan.days[1].meals[0].name).toBe('Cháo yến mạch táo');

      fake.reply({ kind: 'error', status: 500, message: 'temporary upstream error' });
      const fallback = await post('/api/v1/feedback', payload(samplePlan, { eating: 'under' })).expect(200);
      expect(fallback.body.plan.days[1].meals).toEqual(samplePlan.days[1].meals);
      expect(fallback.body.plan.warnings).toContain(WARNINGS.mealsNotRebalanced);
      expect(fake.paths).toHaveLength(2);
    });

    it('creates and saves a new plan on day three, and rejects invalid tokens', async () => {
      await post('/api/v1/feedback', payload(samplePlan, { day_number: 3 }), 'invalid-token').expect(401);
      const { access_token: token, user } = await loginMock(testApp, 'feedback-owner@example.com');
      const original = (await post('/api/v1/generate-plan', PROFILE, token).expect(200)).body;
      const response = await post('/api/v1/feedback', payload(original, { day_number: 3 }), token).expect(200);
      expect(response.body.plan.plan_id).not.toBe(original.plan_id);
      const records = await db.getRepository(PlanRecord).find({ where: { user_id: user.id }, order: { created_at: 'ASC' } });
      expect(records).toHaveLength(2);
      expect(records[1].id).toBe(response.body.plan.plan_id);
      expect(records[1].plan_json.plan_id).toBe(response.body.plan.plan_id);
    });

    it('rejects expired tokens and never stores sensitive restrictions in feedback plans', async () => {
      const { user, access_token: token } = await loginMock(testApp, 'feedback-sensitive@example.com');
      const expired = await testApp.app.get(JwtService).signAsync({ sub: user.id }, { expiresIn: -60 });
      await post('/api/v1/feedback', payload(samplePlan), expired).expect(401);

      const secret = 'DI-UNG-BI-MAT-321';
      const secretProfile = {
        ...PROFILE,
        restrictions: { ...PROFILE.restrictions, allergies: secret },
      };
      fake.reply(
        { kind: 'error', status: 500, message: 'temporary upstream error' },
        { kind: 'error', status: 500, message: 'temporary upstream error' },
      );
      const original = (await post('/api/v1/generate-plan', secretProfile, token).expect(200)).body;
      fake.reply(
        { kind: 'error', status: 500, message: 'temporary upstream error' },
        { kind: 'error', status: 500, message: 'temporary upstream error' },
      );
      const response = await post('/api/v1/feedback', payload(original, { day_number: 3, profile: secretProfile }), token).expect(200);
      const saved = await db.getRepository(PlanRecord).findOneBy({ id: response.body.plan.plan_id });
      expect(JSON.stringify(response.body)).not.toContain(secret);
      expect(JSON.stringify(saved?.plan_json)).not.toContain(secret);
    });

    it('does not update another user’s saved plan and warns when history persistence fails', async () => {
      const owner = await loginMock(testApp, 'feedback-plan-owner@example.com');
      const other = await loginMock(testApp, 'feedback-plan-other@example.com');
      const original = (await post('/api/v1/generate-plan', PROFILE, owner.access_token).expect(200)).body;
      await post('/api/v1/feedback', payload(original), other.access_token).expect(200);
      const unchanged = await db.getRepository(PlanRecord).findOneBy({ id: original.plan_id });
      expect(unchanged?.user_id).toBe(owner.user.id);
      expect(unchanged?.plan_json.days[1].workout.duration_minutes).toBe(original.days[1].workout.duration_minutes);

      const ownerResponse = await post('/api/v1/feedback', payload(original), owner.access_token).expect(200);
      const updated = await db.getRepository(PlanRecord).findOneBy({ id: original.plan_id });
      expect(ownerResponse.body.plan.plan_id).toBe(original.plan_id);
      expect(updated?.plan_json.days[1].workout.duration_minutes).toBe(
        ownerResponse.body.plan.days[1].workout.duration_minutes,
      );
      expect(updated?.plan_json.days[1].workout.duration_minutes).toBeLessThan(original.days[1].workout.duration_minutes);

      const update = vi.spyOn(testApp.app.get(HistoryService), 'update').mockResolvedValue(false);
      try {
        const response = await post('/api/v1/feedback', payload(original), owner.access_token).expect(200);
        expect(response.body.plan.warnings).toContain(WARNINGS.historyNotSaved);
      } finally {
        update.mockRestore();
      }

      const save = vi.spyOn(testApp.app.get(HistoryService), 'save').mockResolvedValue(false);
      try {
        const response = await post('/api/v1/feedback', payload(original, { day_number: 3 }), owner.access_token).expect(200);
        expect(response.body.plan.warnings).toContain(WARNINGS.historyNotSaved);
      } finally {
        save.mockRestore();
      }
    });
  });

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

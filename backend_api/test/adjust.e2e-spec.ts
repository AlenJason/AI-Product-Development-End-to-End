import { readFileSync } from 'node:fs';
import request from 'supertest';
import { DataSource } from 'typeorm';
import { startFakeGemini, type FakeGemini } from './fake-gemini-server.js';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

const SECRET = 'DI-UNG-BI-MAT-321';
const PROFILE = {
  age: 22,
  gender: 'female',
  height_cm: 168,
  weight_kg: 62,
  activity_level: 'light',
  goal: 'cut',
  restrictions: { allergies: SECRET, injuries: '', health_conditions: '' },
};

describe('Đổi món, đổi bài tập, feedback (e2e, chế độ giả lập)', () => {
  let testApp: TestApp;
  const http = () => request(testApp.app.getHttpServer());
  const post = (path: string, body: object, token?: string) => {
    const req = http().post(`/api/v1/${path}`);
    if (token) req.set('Authorization', `Bearer ${token}`);
    return req.send(body);
  };
  const generate = async (token?: string) => (await post('generate-plan', PROFILE, token).expect(200)).body;
  const storedPlan = async (id: string) => {
    const rows: { plan_json: string }[] = await testApp.app
      .get(DataSource)
      .query('SELECT plan_json FROM plan_records WHERE id = ?', [id]);
    return rows[0] ? JSON.parse(rows[0].plan_json) : undefined;
  };

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('swaps a meal and keeps the plan id (FR-4.1)', async () => {
    const plan = await generate();
    const { body } = await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm2_2' }).expect(200);
    expect(body.plan.plan_id).toBe(plan.plan_id);
    expect(body.plan.days[1].meals[1].name).not.toBe(plan.days[1].meals[1].name);
    expect(body.plan.days[1].meals[1].calories).toBe(plan.days[1].meals[1].calories);
  });

  it('swaps an exercise for a lighter one (FR-4.2), or answers 422 when none is lighter', async () => {
    const plan = await generate();
    const { body } = await post('exercises/swap', { profile: PROFILE, plan, exercise_id: 'e1_2' }).expect(200);
    expect(body.plan.days[0].workout.exercises[1].muscle_group).toBe('legs');
    expect(body.plan.days[0].workout.exercises[1].name).not.toBe(plan.days[0].workout.exercises[1].name);
    await post('exercises/swap', { profile: PROFILE, plan, exercise_id: 'e3_2' }).expect(422);
  });

  it('adjusts the next day after feedback (FR-5.2)', async () => {
    const plan = await generate();
    const { body } = await post('feedback', {
      profile: PROFILE,
      plan,
      day_number: 1,
      intensity: 'hard',
      body_states: ['sore'],
      eating: 'on_plan',
    }).expect(200);
    expect(body.safety_warning).toBeNull();
    expect(body.plan.days[1].workout.duration_minutes).toBeLessThan(plan.days[1].workout.duration_minutes);
  });

  it('answers a danger sign with a safety warning and a rest day (#14)', async () => {
    const plan = await generate();
    const { body } = await post('feedback', {
      profile: PROFILE,
      plan,
      day_number: 2,
      intensity: 'easy',
      body_states: ['danger_sign'],
      eating: 'over',
    }).expect(200);
    expect(body.safety_warning.message).toContain('115');
    expect(body.plan.days[2].workout.title).toContain('Nghỉ ngơi');
  });

  it('creates a new plan after feedback on day 3 (FR-5.3)', async () => {
    const plan = await generate();
    const { body } = await post('feedback', {
      profile: PROFILE,
      plan,
      day_number: 3,
      intensity: 'moderate',
      body_states: ['normal'],
      eating: 'on_plan',
    }).expect(200);
    expect(body.plan.plan_id).not.toBe(plan.plan_id);
    expect(body.plan.days).toHaveLength(3);
  });

  it.each<[string, string, (plan: Record<string, unknown>) => object]>([
    ['a malformed meal_id', 'meals/swap', (plan) => ({ profile: PROFILE, plan, meal_id: 'x1_2' })],
    ['a plan edited by hand', 'meals/swap', (plan) => {
      const edited = structuredClone(plan) as { days: { meals: { calories: number }[] }[] };
      edited.days[0].meals[0].calories = 5000;
      return { profile: PROFILE, plan: edited, meal_id: 'm1_1' };
    }],
    ['no body state', 'feedback', (plan) => ({ profile: PROFILE, plan, day_number: 1, intensity: 'hard', body_states: [], eating: 'on_plan' })],
    ['day 4', 'feedback', (plan) => ({ profile: PROFILE, plan, day_number: 4, intensity: 'hard', body_states: ['normal'], eating: 'on_plan' })],
    ['no plan', 'exercises/swap', () => ({ profile: PROFILE, exercise_id: 'e1_1' })],
    ['no profile', 'meals/swap', (plan) => ({ plan, meal_id: 'm1_1' })],
    ['a plan that is not an object', 'meals/swap', () => ({ profile: PROFILE, plan: 'abc', meal_id: 'm1_1' })],
  ])('answers 400 to %s', async (_label, path, build) => {
    await post(path, build(await generate())).expect(400);
  });

  it('answers 409 when the profile changed since the plan was made', async () => {
    const plan = await generate();
    await post('meals/swap', { profile: { ...PROFILE, goal: 'bulk' }, plan, meal_id: 'm1_1' }).expect(409);
  });

  it('never returns or stores the restriction text (#12)', async () => {
    const { access_token } = await loginMock(testApp, 'bi-mat@vku.edu.vn');
    const plan = await generate(access_token);
    const swapped = await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm1_1' }, access_token).expect(200);
    expect(JSON.stringify(swapped.body)).not.toContain(SECRET);
    expect(JSON.stringify(await storedPlan(plan.plan_id))).not.toContain(SECRET);
  });

  describe('lịch sử (quyết định Q4)', () => {
    it('updates the saved plan after a swap when logged in', async () => {
      const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
      const plan = await generate(access_token);
      const { body } = await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm3_3' }, access_token).expect(200);
      const history = await http().get(`/api/v1/plans/history/${plan.plan_id}`).set('Authorization', `Bearer ${access_token}`).expect(200);
      expect(history.body.days[2].meals[2].name).toBe(body.plan.days[2].meals[2].name);
      expect(history.body).toEqual(body.plan);
    });

    it('saves the new plan from day-3 feedback as a new history entry', async () => {
      const { access_token } = await loginMock(testApp, 'binh@vku.edu.vn');
      const plan = await generate(access_token);
      const { body } = await post(
        'feedback',
        { profile: PROFILE, plan, day_number: 3, intensity: 'easy', body_states: ['normal'], eating: 'on_plan' },
        access_token,
      ).expect(200);
      const history = await http().get('/api/v1/plans/history').set('Authorization', `Bearer ${access_token}`).expect(200);
      expect(history.body.plans.map((p: { id: string }) => p.id)).toEqual([body.plan.plan_id, plan.plan_id]);
    });

    it("never touches another user's saved plan, and a guest swap stores nothing", async () => {
      const owner = await loginMock(testApp, 'chu@vku.edu.vn');
      const other = await loginMock(testApp, 'khac@vku.edu.vn');
      const plan = await generate(owner.access_token);
      await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm1_1' }, other.access_token).expect(200);
      await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm1_1' }).expect(200);
      expect(await storedPlan(plan.plan_id)).toEqual(plan);
    });

    it('answers 401 to a bad token instead of skipping history', async () => {
      const plan = await generate();
      await post('meals/swap', { profile: PROFILE, plan, meal_id: 'm1_1' }, 'not-a-jwt').expect(401);
    });
  });

  it('documents the three endpoints in Swagger', async () => {
    const { body } = await http().get('/docs-json').expect(200);
    expect(Object.keys(body.paths)).toEqual(
      expect.arrayContaining(['/api/v1/meals/swap', '/api/v1/exercises/swap', '/api/v1/feedback']),
    );
    expect(body.components.schemas).toHaveProperty('FeedbackResponseDto');
  });
});

describe('Đổi món qua SDK thật + server Gemini giả (e2e)', () => {
  const SAMPLE_CONTENT: unknown = JSON.parse(
    readFileSync(new URL('../src/plan/data/sample-plan.json', import.meta.url), 'utf-8'),
  );
  const PROFILE_OK = { ...PROFILE, restrictions: { allergies: 'Đậu phộng', injuries: '', health_conditions: '' } };
  let testApp: TestApp;
  let fake: FakeGemini;

  beforeAll(async () => {
    fake = await startFakeGemini();
    testApp = await createTestApp({ GEMINI_API_KEY: 'test-key', GEMINI_BASE_URL: fake.url, GEMINI_TIMEOUT_MS: '200' });
  });

  afterAll(async () => {
    await testApp.close();
    await fake.close();
  });

  it('uses the dish Gemini suggests when it passes every check', async () => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
    const { body: plan } = await request(testApp.app.getHttpServer()).post('/api/v1/generate-plan').send(PROFILE_OK).expect(200);
    const lunch = plan.days[0].meals[1];

    fake.reply({
      kind: 'json',
      body: {
        meal_type: 'lunch',
        name: 'Cơm cá hồi áp chảo, canh bí',
        portion: '1 chén cơm + 1 miếng cá',
        calories: lunch.calories,
        protein_g: (lunch.calories * 0.25) / 4,
        carbs_g: (lunch.calories * 0.5) / 4,
        fat_g: (lunch.calories * 0.25) / 9,
        ingredients: [{ name: 'Cá hồi', amount: 120, unit: 'g', category: 'protein' }],
      },
    });
    const { body } = await request(testApp.app.getHttpServer())
      .post('/api/v1/meals/swap')
      .send({ profile: PROFILE_OK, plan, meal_id: 'm1_2' })
      .expect(200);
    expect(fake.requests).toHaveLength(1);
    expect(fake.requests[0]).toContain('du_lieu_nguoi_dung');
    expect(body.plan.days[0].meals[1].name).toBe('Cơm cá hồi áp chảo, canh bí');
  });

  it('falls back to the pool after a Gemini timeout, without retrying (#15)', async () => {
    fake.reply({ kind: 'json', body: SAMPLE_CONTENT });
    const { body: plan } = await request(testApp.app.getHttpServer()).post('/api/v1/generate-plan').send(PROFILE_OK).expect(200);
    fake.reply({ kind: 'hang' });
    const { body } = await request(testApp.app.getHttpServer())
      .post('/api/v1/meals/swap')
      .send({ profile: PROFILE_OK, plan, meal_id: 'm1_2' })
      .expect(200);
    expect(fake.requests).toHaveLength(1);
    expect(body.plan.days[0].meals[1].name).not.toBe(plan.days[0].meals[1].name);
  });
});

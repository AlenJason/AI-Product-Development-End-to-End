import { JwtService } from '@nestjs/jwt';
import request from 'supertest';
import { DataSource } from 'typeorm';
import { createTestApp, loginMock, type TestApp } from './test-app.js';

const HEALTH_SECRET = 'BENH-NEN-BI-MAT-456';
const ALLERGY_SECRET = 'DI-UNG-BI-MAT-789';
const PROFILE = {
  age: 22,
  gender: 'female',
  height_cm: 168,
  weight_kg: 62,
  activity_level: 'light',
  goal: 'cut',
  restrictions: { allergies: ALLERGY_SECRET, injuries: '', health_conditions: HEALTH_SECRET },
};

describe('Lịch sử kế hoạch (e2e, AUTH_MODE=mock, DB trong RAM)', () => {
  let testApp: TestApp;
  const http = () => request(testApp.app.getHttpServer());
  const generate = (authorization?: string) => {
    const req = http().post('/api/v1/generate-plan');
    if (authorization) req.set('Authorization', authorization);
    return req.send(PROFILE);
  };
  const history = (token: string, id?: string) =>
    http()
      .get(id ? `/api/v1/plans/history/${id}` : '/api/v1/plans/history')
      .set('Authorization', `Bearer ${token}`);
  const db = () => testApp.app.get(DataSource);
  const countPlans = async (): Promise<number> =>
    (await db().query('SELECT COUNT(*) AS n FROM plan_records'))[0].n;

  beforeAll(async () => {
    testApp = await createTestApp();
  });

  afterAll(async () => {
    await testApp.close();
  });

  it('saves a plan generated while logged in and serves it back unchanged', async () => {
    const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
    const { body: plan } = await generate(`Bearer ${access_token}`).expect(200);

    const { body: list } = await history(access_token).expect(200);
    expect(list.plans[0]).toEqual({
      id: plan.plan_id,
      created_at: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/),
      target_calories: plan.daily_target.target_calories,
    });
    const { body: saved } = await history(access_token, plan.plan_id).expect(200);
    expect(saved).toEqual(plan);
  });

  it('lists the newest plan first', async () => {
    const { access_token } = await loginMock(testApp, 'lich-su@vku.edu.vn');
    const { body: older } = await generate(`Bearer ${access_token}`).expect(200);
    await new Promise((resolve) => setTimeout(resolve, 5)); // created_at chính xác tới mili-giây
    const { body: newer } = await generate(`Bearer ${access_token}`).expect(200);
    const { body } = await history(access_token).expect(200);
    expect(body.plans.map((plan: { id: string }) => plan.id)).toEqual([newer.plan_id, older.plan_id]);
  });

  it('does not save a plan generated without a token', async () => {
    const before = await countPlans();
    await generate().expect(200);
    expect(await countPlans()).toBe(before);
  });

  it.each([
    ['a token that is not a JWT', 'Bearer not-a-jwt'],
    ['a malformed header', 'Token abc'],
  ])('rejects generate-plan with %s instead of silently skipping history', async (_label, header) => {
    const before = await countPlans();
    await generate(header).expect(401);
    expect(await countPlans()).toBe(before);
  });

  it('requires a valid token for history', async () => {
    const { user } = await loginMock(testApp, 'an@vku.edu.vn');
    const forged = await new JwtService({ secret: 'someone-elses-secret-at-least-32-chars' }).signAsync({
      sub: user.id,
    });
    await http().get('/api/v1/plans/history').expect(401);
    await history('not-a-jwt').expect(401);
    await history(forged).expect(401);
  });

  it("hides another user's plan behind 404", async () => {
    const an = await loginMock(testApp, 'an@vku.edu.vn');
    const binh = await loginMock(testApp, 'binh@vku.edu.vn');
    const { body: plan } = await generate(`Bearer ${an.access_token}`).expect(200);
    await history(binh.access_token, plan.plan_id).expect(404);
    const { body } = await history(binh.access_token).expect(200);
    expect(body.plans.map((p: { id: string }) => p.id)).not.toContain(plan.plan_id);
  });

  it('answers 400 to an id that is not a UUID, and 401 first when not logged in', async () => {
    const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
    await history(access_token, 'abc').expect(400);
    await http().get('/api/v1/plans/history/abc').expect(401);
  });

  it('never stores the health and allergy text (NFR-7, #12)', async () => {
    const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
    await generate(`Bearer ${access_token}`).expect(200);
    const rows: { plan_json: string }[] = await db().query('SELECT plan_json FROM plan_records');
    const stored = rows.map((row) => row.plan_json).join('\n');
    expect(rows.length).toBeGreaterThan(0);
    expect(stored).not.toContain(HEALTH_SECRET);
    expect(stored).not.toContain(ALLERGY_SECRET);
  });

  it('deletes the history together with the account', async () => {
    const { access_token, user } = await loginMock(testApp, 'xoa@vku.edu.vn');
    await generate(`Bearer ${access_token}`).expect(200);
    await http().delete('/api/v1/me').set('Authorization', `Bearer ${access_token}`).expect(204);

    await history(access_token).expect(401);
    const rows = await db().query('SELECT COUNT(*) AS n FROM plan_records WHERE user_id = ?', [user.id]);
    expect(rows[0].n).toBe(0);
    const again = await loginMock(testApp, 'xoa@vku.edu.vn');
    expect((await history(again.access_token).expect(200)).body).toEqual({ plans: [] });
  });

  it('documents the history endpoints in Swagger', async () => {
    const { body } = await http().get('/docs-json').expect(200);
    expect(Object.keys(body.paths)).toEqual(
      expect.arrayContaining(['/api/v1/plans/history', '/api/v1/plans/history/{id}']),
    );
    expect(body.components.schemas).toHaveProperty('PlanHistoryResponseDto');
  });
});

describe('Lưu lịch sử thất bại (e2e)', () => {
  it('still returns the plan, with a warning, when history cannot be saved', async () => {
    const testApp = await createTestApp();
    try {
      const { access_token } = await loginMock(testApp, 'an@vku.edu.vn');
      await testApp.app.get(DataSource).query('DROP TABLE plan_records');
      const { body } = await request(testApp.app.getHttpServer())
        .post('/api/v1/generate-plan')
        .set('Authorization', `Bearer ${access_token}`)
        .send(PROFILE)
        .expect(200);
      expect(body.days).toHaveLength(3);
      expect(body.warnings.some((warning: string) => warning.startsWith('Chưa lưu được kế hoạch'))).toBe(true);
    } finally {
      await testApp.close();
    }
  });
});

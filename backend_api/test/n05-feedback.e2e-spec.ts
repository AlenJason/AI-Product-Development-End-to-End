import request from 'supertest';
import { createTestApp, loginMock, type TestApp } from './test-app.js';
import { makeProfile, geminiOff } from './plan-fixtures.js';
import { PlanService } from '../src/plan/plan.service.js';
import { FeedbackService } from '../src/plan/adjust/feedback.service.js';
import { FeedbackReceipt } from '../src/database/entities/feedback-receipt.entity.js';
import { DataSource } from 'typeorm';

describe('N05 HTTP daily lifecycle and durable lock', () => {
  let app: TestApp;
  beforeEach(async () => {
    app = await createTestApp();
  });
  afterEach(async () => {
    await app.close();
  });
  const post = (path: string, body: object, token?: string) => {
    const req = request(app.app.getHttpServer()).post(`/api/v1/${path}`);
    return (token ? req.set('Authorization', `Bearer ${token}`) : req).send(
      body,
    );
  };
  it('generates, swaps, adjusts three days, replays exactly and creates only one cycle', async () => {
    const profile = makeProfile();
    let plan = (await post('generate-plan', profile).expect(200)).body;
    plan = (
      await post('meals/swap', { profile, plan, meal_id: 'm1_2' }).expect(200)
    ).body.plan;
    const firstDay = plan.days[0];
    const body = (day: number) => ({
      profile,
      plan,
      day_number: day,
      intensity: 'hard',
      body_states: ['normal'],
      eating: 'on_plan',
    });
    const first = body(1),
      one = (await post('feedback', first).expect(200)).body;
    expect(one.plan.days[0]).toEqual(firstDay);
    expect(one.plan.days[2]).toEqual(plan.days[2]);
    expect((await post('feedback', first).expect(200)).body).toEqual(one);
    await post('feedback', { ...first, eating: 'under' }).expect(409);
    plan = one.plan;
    const two = (await post('feedback', body(2)).expect(200)).body;
    expect(two.plan.days.slice(0, 2)).toEqual(plan.days.slice(0, 2));
    plan = two.plan;
    const three = body(3),
      results = await Promise.all([
        post('feedback', three),
        post('feedback', three),
      ]);
    expect(results.map((r) => r.status)).toEqual([200, 200]);
    expect(results[0].body).toEqual(results[1].body);
    expect(results[0].body.plan.plan_id).not.toBe(plan.plan_id);
    // Recreate service with empty in-process maps, retaining actual migrated SQLite.
    const db = app.app.get(DataSource);
    const fresh = new FeedbackService(
      geminiOff,
      new PlanService(geminiOff),
      db,
    );
    expect(
      (await fresh.apply(three as Parameters<FeedbackService['apply']>[0]))
        .response,
    ).toEqual(results[0].body);
    expect(await db.getRepository(FeedbackReceipt).count()).toBe(3);
  });
  it('replaying day 1 cannot overwrite later feedback in authenticated history', async () => {
    const auth = await loginMock(app, 'n05-history@example.com'),
      profile = makeProfile();
    const plan = (
      await post('generate-plan', profile, auth.access_token).expect(200)
    ).body;
    const first = {
      profile,
      plan,
      day_number: 1,
      intensity: 'hard',
      body_states: ['normal'],
      eating: 'on_plan',
    };
    const one = (await post('feedback', first, auth.access_token).expect(200))
      .body;
    const two = (
      await post(
        'feedback',
        { ...first, plan: one.plan, day_number: 2 },
        auth.access_token,
      ).expect(200)
    ).body;
    await post('feedback', first, auth.access_token).expect(200);
    const history = await request(app.app.getHttpServer())
      .get(`/api/v1/plans/history/${plan.plan_id}`)
      .set('Authorization', `Bearer ${auth.access_token}`)
      .expect(200);
    expect(history.body).toEqual(two.plan);
  });
});

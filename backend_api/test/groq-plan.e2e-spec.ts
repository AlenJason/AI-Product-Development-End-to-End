import request from 'supertest';
import { createTestApp, type TestApp } from './test-app.js';
import { samplePlan, makeProfile } from './plan-fixtures.js';

describe('Groq create-plan HTTP pipeline', () => {
  let app: TestApp;
  beforeAll(async () => {
    app = await createTestApp({
      PLAN_AI_PROVIDER: 'groq',
      GROQ_API_KEY: 'synthetic-key',
    });
  });
  afterEach(() => vi.unstubAllGlobals());
  afterAll(async () => app.close());

  it('returns Groq source and assembled grocery list through the real endpoint', async () => {
    const sample = await samplePlan();
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValue(
          new Response(
            JSON.stringify({
              choices: [
                {
                  finish_reason: 'stop',
                  message: { content: JSON.stringify({ days: sample.days }) },
                },
              ],
            }),
          ),
        ),
    );
    const res = await request(app.app.getHttpServer())
      .post('/api/v1/generate-plan')
      .send(makeProfile())
      .expect(200);
    expect(res.body.source).toBe('groq');
    expect(res.body.days).toHaveLength(3);
    expect(res.body.grocery_list.length).toBeGreaterThan(0);
    expect(res.body.plan_id).toBeTruthy();
  });

  it('returns sample rather than claiming Groq success on provider rejection', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(new Response('{}', { status: 403 })),
    );
    const res = await request(app.app.getHttpServer())
      .post('/api/v1/generate-plan')
      .send(makeProfile())
      .expect(200);
    expect(res.body.source).toBe('sample');
  });

  it('routes meal swap, exercise swap, feedback and day-three generation through Groq', async () => {
    const profile = makeProfile();
    const plan = await samplePlan(profile);
    plan.source = 'groq' as typeof plan.source;
    const reply = (content: unknown) => {
      const mock = vi
        .fn()
        .mockImplementation(() =>
          Promise.resolve(
            new Response(
              JSON.stringify({
                choices: [
                  {
                    finish_reason: 'stop',
                    message: { content: JSON.stringify(content) },
                  },
                ],
              }),
            ),
          ),
        );
      vi.stubGlobal('fetch', mock);
      return mock;
    };
    const meal = { ...plan.days[0].meals[1], name: 'Cơm gà rau củ thử nghiệm' };
    let mock = reply(meal);
    const swapped = await request(app.app.getHttpServer())
      .post('/api/v1/meals/swap')
      .send({ profile, plan, meal_id: 'm1_2' })
      .expect(200);
    expect(swapped.body.plan.days[0].meals[1].name).toBe(meal.name);
    expect(mock).toHaveBeenCalledTimes(1);

    const exercise = {
      name: 'Cầu mông (Glute bridge)',
      sets: 2,
      reps_or_duration: '10 lần',
      muscle_group: 'legs',
      tags: [],
    };
    mock = reply(exercise);
    const workout = await request(app.app.getHttpServer())
      .post('/api/v1/exercises/swap')
      .send({ profile, plan, exercise_id: 'e1_2' })
      .expect(200);
    expect(workout.body.plan.days[0].workout.exercises[1].name).toBe(
      exercise.name,
    );
    expect(mock).toHaveBeenCalledTimes(1);

    const meals = plan.days[1].meals.map((m, i) => ({
      ...m,
      name: `Món cân đối thử nghiệm ${i}`,
    }));
    mock = reply({ meals });
    const feedback = await request(app.app.getHttpServer())
      .post('/api/v1/feedback')
      .send({
        profile,
        plan,
        day_number: 1,
        intensity: 'moderate',
        body_states: ['normal'],
        eating: 'under',
      })
      .expect(200);
    expect(feedback.body.plan.days[1].meals[0].name).toBe(meals[0].name);
    expect(mock).toHaveBeenCalledTimes(1);

    mock = reply({ days: plan.days });
    const next = await request(app.app.getHttpServer())
      .post('/api/v1/feedback')
      .send({
        profile,
        plan,
        day_number: 3,
        intensity: 'moderate',
        body_states: ['normal'],
        eating: 'on_plan',
      })
      .expect(200);
    expect(next.body.plan.source).toBe('groq');
    expect(next.body.plan.plan_id).not.toBe(plan.plan_id);
    expect(mock).toHaveBeenCalledTimes(1);

    mock = reply({});
    const danger = await request(app.app.getHttpServer())
      .post('/api/v1/feedback')
      .send({
        profile,
        plan: {...plan,plan_id: next.body.plan.plan_id},
        day_number: 1,
        intensity: 'hard',
        body_states: ['danger_sign'],
        eating: 'over',
      })
      .expect(200);
    expect(danger.body.safety_warning).toBeTruthy();
    expect(mock).not.toHaveBeenCalled();
  });
});

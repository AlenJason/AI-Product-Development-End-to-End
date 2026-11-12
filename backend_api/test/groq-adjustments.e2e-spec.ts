import request from 'supertest';
import { readFileSync } from 'node:fs';
import { PLAN_AI } from '../src/plan/ai-provider.js';
import { GeminiService } from '../src/plan/gemini.service.js';
import { GroqPlanService } from '../src/plan/groq-plan.service.js';
import { makeProfile, samplePlan } from './plan-fixtures.js';
import { createTestApp, type TestApp } from './test-app.js';
import type { MealPlanResponseDto } from '../src/plan/dto/meal-plan-response.dto.js';

describe('Groq all-task HTTP routing and failure contracts (no live calls)', () => {
  const recorded = JSON.parse(
    readFileSync(
      new URL('./fixtures/groq-exercise-load-conflicts.json', import.meta.url),
      'utf8',
    ),
  ) as { days: { workout: { exercises: unknown[] } }[] }[];
  for (const [index, record] of recorded.entries()) {
    it(`real recorded response ${index + 1} passes HTTP pipeline after verified repairs/replacements`, async () => {
      const older = makeProfile({ age: 65 }, { injuries: 'Đầu gối' }),
        base = await samplePlan(older);
      const wire = reply({
        days: base.days.map((day, i) => ({
          ...day,
          workout: {
            ...day.workout,
            exercises: record.days[i].workout.exercises,
          },
        })),
      });
      const res = await request(app.app.getHttpServer())
        .post('/api/v1/generate-plan')
        .send(older)
        .expect(200);
      expect(res.body.source).toBe('groq');
      expect(wire).toHaveBeenCalledTimes(1);
      expect(
        res.body.days.map((d: { meals: { name: string }[] }) =>
          d.meals.map((m) => m.name),
        ),
      ).toEqual(base.days.map((d) => d.meals.map((m) => m.name)));
      expect(res.body.warnings.join()).toContain('đã được thay');
      expect(JSON.stringify(res.body)).not.toContain('assessment');
      for (const day of res.body.days)
        for (const exercise of day.workout.exercises) {
          expect(exercise.tags).not.toContain('kneeling');
          expect(exercise.tags).not.toContain('jumping');
        }
    });
  }
  let app: TestApp, plan: MealPlanResponseDto;
  const profile = makeProfile();
  function profileProposal(p: ReturnType<typeof makeProfile>) {
    return {
      name: 'Đứng nâng mũi chân hai bên',
      sets: 2,
      reps_or_duration: '8 lần',
      muscle_group: 'legs',
      tags: [],
      assessment: {
        difficulty_level: 1,
        equipment: 'none',
        impact: 'low',
        instructions:
          'Đứng bằng hai chân, nhấc nhẹ hai mũi chân rồi hạ xuống chậm, không nhảy.',
        movement: {
          position: 'standing',
          balance: 'stable',
          tempo: 'controlled',
        },
        profile_fit: {
          age: p.age,
          activity_level: p.activity_level,
          restrictions_considered: true,
          reason:
            'Chọn vận động đứng nhịp chậm, xét tuổi và hạn chế đã khai trong hồ sơ.',
        },
      },
    };
  }
  it('Generate sends health context to Groq and retains a valid new exercise outside the pool', async () => {
    const p = makeProfile(
        { age: 65 },
        { health_conditions: 'tăng huyết áp', injuries: 'đau gối' },
      ),
      base = await samplePlan(p),
      proposal = profileProposal(p);
    const wire = reply({
      days: base.days.map((day) => ({
        ...day,
        workout: { ...day.workout, exercises: [proposal] },
      })),
    });
    const res = await request(app.app.getHttpServer())
      .post('/api/v1/generate-plan')
      .send(p)
      .expect(200);
    const prompt = JSON.parse(wire.mock.calls[0][1].body).messages[0].content;
    expect(prompt).toContain('"age":65');
    expect(prompt).toContain('tăng huyết áp');
    expect(prompt).toContain('đau gối');
    expect(prompt).not.toContain('Metadata tham khảo từ dữ liệu dự án');
    expect(res.body.source).toBe('groq');
    expect(
      res.body.days.every(
        (d: { workout: { exercises: { name: string }[] } }) =>
          d.workout.exercises[0].name === proposal.name,
      ),
    ).toBe(true);
    expect(JSON.stringify(res.body)).not.toContain('profile_fit');
    expect(wire).toHaveBeenCalledTimes(1);
  });
  it('Exercise Swap accepts the profile-based new exercise through the HTTP contract', async () => {
    const proposal = profileProposal(profile),
      wire = reply(proposal);
    const res = await post('exercises/swap', { exercise_id: 'e1_2' }).expect(
      200,
    );
    expect(res.body.plan.days[0].workout.exercises[1].name).toBe(proposal.name);
    expect(res.body.plan.warnings.join()).toContain('[AI:exercise-swap:groq]');
    expect(wire).toHaveBeenCalledTimes(1);
  });
  const exercise = {
    name: 'Cầu mông (Glute bridge)',
    sets: 2,
    reps_or_duration: '10 lần',
    muscle_group: 'legs',
    tags: [],
  };
  beforeAll(async () => {
    app = await createTestApp({
      PLAN_AI_PROVIDER: 'groq',
      GROQ_API_KEY: 'synthetic-key',
    });
  });
  beforeEach(async () => {
    plan = await samplePlan(profile);
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });
  afterAll(async () => app.close());
  const post = (path: string, body: object) =>
    request(app.app.getHttpServer())
      .post(`/api/v1/${path}`)
      .send({ profile, plan, ...body });
  function reply(content: unknown) {
    const mock = vi.fn().mockImplementation(() =>
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
  }
  it('all tokens reference the same selected Groq instance, not a Google client', () => {
    expect(app.app.get(PLAN_AI)).toBe(app.app.get(GroqPlanService));
    expect(app.app.get(GeminiService)).toBe(app.app.get(PLAN_AI));
  });
  it('generate replaces an unverified age65 proposal without discarding AI meals', async () => {
    const older = makeProfile({ age: 65 });
    const sample = await samplePlan(older);
    const proposal = {
      name: 'Đứng đưa chân sang ngang chậm',
      sets: 2,
      reps_or_duration: '8 lần',
      muscle_group: 'legs',
      tags: [],
      assessment: {
        difficulty_level: 1,
        equipment: 'none',
        impact: 'low',
        instructions:
          'Đứng thẳng, đưa một chân sang bên chậm rồi trở về vị trí ban đầu.',
      },
    };
    const fetch = reply({
      days: sample.days.map((day) => ({
        ...day,
        workout: { ...day.workout, exercises: [proposal] },
      })),
    });
    const res = await request(app.app.getHttpServer())
      .post('/api/v1/generate-plan')
      .send(older)
      .expect(200);
    expect(res.body.source).toBe('groq');
    expect(res.body.days[0].workout.exercises[0].name).not.toBe(proposal.name);
    expect(res.body.warnings.join()).toContain('đã được thay');
    expect(JSON.stringify(res.body)).not.toContain('assessment');
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it('exercise swap rejects self-assessed unknown identity and uses verified fallback', async () => {
    const proposal = {
      name: 'Đứng đưa chân sang ngang chậm',
      sets: 2,
      reps_or_duration: '8 lần',
      muscle_group: 'legs',
      tags: [],
      assessment: {
        difficulty_level: 1,
        equipment: 'none',
        impact: 'low',
        instructions:
          'Đứng thẳng, đưa một chân sang bên chậm rồi trở về vị trí ban đầu.',
      },
    };
    const fetch = reply(proposal);
    const res = await post('exercises/swap', { exercise_id: 'e1_2' }).expect(
      200,
    );
    expect(res.body.plan.days[0].workout.exercises[1].name).not.toBe(
      proposal.name,
    );
    expect(res.body.plan.warnings.join()).toContain(
      '[AI:exercise-swap:fallback]',
    );
    expect(fetch).toHaveBeenCalledTimes(2);
    expect(JSON.stringify(res.body)).not.toContain('assessment');
  });
  it('outside proposal with excessive workload fails validation and falls back', async () => {
    const proposal = {
      name: 'Đứng đưa chân sang ngang chậm',
      sets: 6,
      reps_or_duration: '500 lần',
      muscle_group: 'legs',
      tags: [],
      assessment: {
        difficulty_level: 1,
        equipment: 'none',
        impact: 'low',
        instructions:
          'Đứng thẳng, đưa một chân sang bên chậm rồi trở về vị trí ban đầu.',
      },
    };
    reply(proposal);
    const res = await post('exercises/swap', { exercise_id: 'e1_2' }).expect(
      200,
    );
    expect(res.body.plan.days[0].workout.exercises[1].name).not.toBe(
      proposal.name,
    );
    expect(res.body.plan.warnings.join()).toContain(
      '[AI:exercise-swap:fallback]',
    );
  });
  it('exercise swap calls actual Groq HTTP client once and keeps response envelope/IDs', async () => {
    const fetch = reply(exercise);
    const res = await post('exercises/swap', { exercise_id: 'e1_2' }).expect(
      200,
    );
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(fetch.mock.calls[0][0]).toBe(
      'https://api.groq.com/openai/v1/chat/completions',
    );
    const body = JSON.parse(fetch.mock.calls[0][1].body);
    expect(body.response_format).toEqual({ type: 'json_object' });
    expect(res.body.plan.plan_id).toBe(plan.plan_id);
    expect(res.body.plan.days[0].workout.exercises[1]).toMatchObject({
      ...exercise,
      exercise_id: 'e1_2',
    });
    expect(res.body.plan.warnings.join()).toContain('[AI:exercise-swap:groq]');
  });
  it('meal swap rebuilds grocery using the valid Groq result and reports source', async () => {
    const meal = {
      ...plan.days[0].meals[1],
      name: 'Món Groq mới',
      ingredients: [
        { name: 'Gạo lứt mới', amount: 120, unit: 'g', category: 'pantry' },
      ],
    };
    reply(meal);
    const res = await post('meals/swap', { meal_id: 'm1_2' }).expect(200);
    expect(res.body.plan.warnings.join()).toContain('[AI:meal-swap:groq]');
    expect(JSON.stringify(res.body.plan.grocery_list)).toContain('Gạo lứt mới');
    expect(res.body.plan.days[0].meals[1].meal_id).toBe('m1_2');
  });
  for (const path of ['exercises/swap', 'meals/swap']) {
    const payload = () =>
      path.startsWith('exercises')
        ? { exercise_id: 'e1_2' }
        : { meal_id: 'm1_2' };
    for (const scenario of [
      'schema',
      'invalid-json',
      'timeout',
      'rate-limit',
      'server-error',
    ]) {
      it(`${path}: ${scenario} uses validated fallback with bounded retry`, async () => {
        let fetch;
        if (scenario === 'schema') fetch = reply({ bad: true });
        else {
          fetch = vi.fn().mockImplementation(() => {
            if (scenario === 'timeout')
              return Promise.reject(
                new DOMException('private text', 'TimeoutError'),
              );
            if (scenario === 'invalid-json')
              return Promise.resolve(
                new Response(
                  JSON.stringify({
                    choices: [
                      { finish_reason: 'stop', message: { content: '{' } },
                    ],
                  }),
                ),
              );
            return Promise.resolve(
              new Response('private body', {
                status: scenario === 'rate-limit' ? 429 : 503,
              }),
            );
          });
          vi.stubGlobal('fetch', fetch);
        }
        const res = await post(path, payload()).expect(200);
        expect(res.body.plan.warnings.join()).toContain(':fallback]');
        expect(fetch).toHaveBeenCalledTimes(
          ['timeout', 'rate-limit'].includes(scenario) ? 1 : 2,
        );
      });
    }
  }
  it('no fitting lighter exercise returns 422 and does not mutate input', async () => {
    const before = structuredClone(plan);
    reply({ bad: true });
    await post('exercises/swap', { exercise_id: 'e3_2' }).expect(422);
    expect(plan).toEqual(before);
  });
  it('allergen Groq result and exhausted meal pool return controlled 422', async () => {
    reply({
      ...plan.days[0].meals[1],
      name: 'Món mới',
      ingredients: [
        { name: 'Tôm', amount: 100, unit: 'g', category: 'protein' },
      ],
    });
    await post('meals/swap', {
      meal_id: 'm1_2',
      profile: makeProfile(
        {},
        { allergies: 'hải sản, thịt bò, đậu phụ, thịt heo, gà' },
      ),
    }).expect(422);
  });
  it('feedback calls Groq once for identical concurrent/retried requests and changes only next day', async () => {
    const meals = plan.days[1].meals.map((m, i) => ({
      ...m,
      name: `Món sau phản hồi ${i}`,
    }));
    const fetch = reply({ meals });
    const body = {
      day_number: 1,
      intensity: 'moderate',
      body_states: ['normal'],
      eating: 'under',
    };
    const [one, two] = await Promise.all([
      post('feedback', body).expect(200),
      post('feedback', body).expect(200),
    ]);
    await post('feedback', body).expect(200);
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(one.body).toEqual(two.body);
    expect(one.body.plan.days[0]).toEqual(plan.days[0]);
    expect(one.body.plan.days[2]).toEqual(plan.days[2]);
    expect(one.body.plan.warnings.join()).toContain('[AI:feedback-meals:groq]');
  });
  it('feedback rebalance failure preserves meals and gives explicit fallback', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValue(new Response('{}', { status: 429 }));
    vi.stubGlobal('fetch', fetch);
    const res = await post('feedback', {
      day_number: 1,
      intensity: 'moderate',
      body_states: ['normal'],
      eating: 'under',
    }).expect(200);
    expect(res.body.plan.days[1].meals).toEqual(plan.days[1].meals);
    expect(res.body.plan.warnings.join()).toContain(
      '[AI:feedback-meals:fallback]',
    );
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it('failed day3 generation returns 422 instead of silently replacing old cycle', async () => {
    const fetch = vi
      .fn()
      .mockResolvedValue(new Response('{}', { status: 429 }));
    vi.stubGlobal('fetch', fetch);
    await post('feedback', {
      day_number: 3,
      intensity: 'moderate',
      body_states: ['normal'],
      eating: 'on_plan',
    }).expect(422);
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it('danger signs on day3 skip AI and return safety warning/rest', async () => {
    const fetch = reply({});
    const res = await post('feedback', {
      day_number: 3,
      intensity: 'hard',
      body_states: ['danger_sign'],
      eating: 'over',
    }).expect(200);
    expect(fetch).not.toHaveBeenCalled();
    expect(res.body.safety_warning.message).toBeTruthy();
    expect(res.body.plan.source).toBe('sample');
  });
});

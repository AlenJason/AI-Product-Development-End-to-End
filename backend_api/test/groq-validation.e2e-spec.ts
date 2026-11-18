import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import request from 'supertest';
import { createTestApp, type TestApp } from './test-app.js';
import { geminiOff, makeProfile, samplePlan } from './plan-fixtures.js';
import { GroqPlanService } from '../src/plan/groq-plan.service.js';
import { PlanService } from '../src/plan/plan.service.js';
import { parsePlanContent } from '../src/plan/plan-validation.js';
import { ActivityLevel } from '../src/plan/enums/activity-level.enum.js';

// Local HTTP stand-in. The real provider serializes, sends, parses and aborts
// real HTTP; this routing adapter changes only the destination during tests.
// Any origin other than the exact Groq endpoint is rejected, never forwarded.
describe('Groq validation repair through Nest and local upstream HTTP', () => {
  let app: TestApp;
  const warningCalls: unknown[][] = [];
  let baseUrl: string;
  let responses: { status?: number; content?: unknown; hang?: boolean }[] = [];
  const observed: { path: string; method: string; body: any }[] = [];
  const upstream = createServer((req, res) => {
    let body = '';
    req.on('data', (chunk: Buffer) => {
      body += chunk.toString();
    });
    req.on('end', () => {
      observed.push({
        path: req.url!,
        method: req.method!,
        body: JSON.parse(body),
      });
      if (req.url !== '/openai/v1/chat/completions') {
        res.writeHead(501).end();
        return;
      }
      const next = responses.shift() ?? { status: 501 };
      if (next.hang) return;
      res.writeHead(next.status ?? 200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify(
          next.status
            ? { error: 'synthetic private provider error' }
            : {
                choices: [
                  {
                    finish_reason: 'stop',
                    message: { content: JSON.stringify(next.content) },
                  },
                ],
              },
        ),
      );
    });
  });

  beforeAll(async () => {
    await new Promise<void>((resolve) =>
      upstream.listen(0, '127.0.0.1', resolve),
    );
    baseUrl = `http://127.0.0.1:${(upstream.address() as AddressInfo).port}`;
    app = await createTestApp({
      PLAN_AI_PROVIDER: 'groq',
      GROQ_API_KEY: 'synthetic-http-key',
    });
  });
  beforeEach(() => {
    responses = [];
    observed.length = 0;
    warningCalls.length = 0;
    vi.spyOn(Logger.prototype, 'warn').mockImplementation(
      (...args: unknown[]) => {
        warningCalls.push(args);
      },
    );
    const realFetch = globalThis.fetch;
    vi.stubGlobal(
      'fetch',
      (input: string | URL | Request, init?: RequestInit) => {
        const url = input instanceof Request ? input.url : String(input);
        if (url !== 'https://api.groq.com/openai/v1/chat/completions')
          throw new Error('Unexpected upstream origin blocked');
        return realFetch(baseUrl + '/openai/v1/chat/completions', init);
      },
    );
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });
  afterAll(async () => {
    await app.close();
    upstream.closeAllConnections();
    await new Promise<void>((resolve) => upstream.close(() => resolve()));
  });

  it('repairs numeric/schema errors over real HTTP and returns the same Flutter contract', async () => {
    const profile = makeProfile();
    const good = { days: (await samplePlan(profile)).days };
    const bad = structuredClone(good);
    (bad.days[1].meals[2] as any).calories = '500';
    responses = [{ content: bad }, { content: good }];
    const res = await request(app.app.getHttpServer())
      .post('/api/v1/generate-plan')
      .send(profile)
      .expect(200);
    expect(observed).toHaveLength(2);
    expect(
      observed.every(
        (r) => r.path === '/openai/v1/chat/completions' && r.method === 'POST',
      ),
    ).toBe(true);
    expect(observed[0].body.messages[0].content).not.toContain(
      '<plan_validation_feedback>',
    );
    expect(observed[1].body.messages[0].content).toContain(
      'days[1].meals[2].calories',
    );
    expect(observed[1].body.messages[0].content).toContain('"code":"TYPE"');
    expect(res.body.source).toBe('groq');
    expect(res.body.plan_id).toMatch(/^[0-9a-f-]{36}$/);
    expect(res.body.days[0].meals[0].meal_id).toBe('m1_1');
    expect(res.body.grocery_list.length).toBeGreaterThan(0);
    expect(
      parsePlanContent({ days: res.body.days }, res.body.daily_target).errors,
    ).toEqual([]);
    expect(Object.keys(res.body).sort()).toEqual([
      'daily_target',
      'days',
      'grocery_list',
      'plan_id',
      'source',
      'warnings',
    ]);
  });

  it('reports one then two semantic errors without assuming attempt two must improve', async () => {
    const good = { days: (await samplePlan()).days };
    const first = structuredClone(good),
      second = structuredClone(good);
    first.days[0].meals[0].protein_g = 9999;
    second.days[0].meals[0].protein_g = 9999;
    second.days[1].meals[2].protein_g = 9999;
    responses = [{ content: first }, { content: second }];
    const res = await request(app.app.getHttpServer())
      .post('/api/v1/generate-plan')
      .send(makeProfile())
      .expect(200);
    expect(res.body.source).toBe('sample');
    expect(observed).toHaveLength(2);
    const events = warningCalls
      .map(([line]) => String(line))
      .filter((line) => line.includes('plan_validation_failed'))
      .map((line) => JSON.parse(line));
    expect(events.map((e) => e.error_count)).toEqual([1, 2]);
    expect(events[1].issues).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: 'MACRO_CALORIES',
          path: 'days[1].meals[2]',
        }),
      ]),
    );
  });

  it('rejects missing workout cleanly and retries once instead of crashing in restrictions', async () => {
    const good = { days: (await samplePlan()).days };
    const bad = JSON.parse(JSON.stringify(good));
    delete bad.days[2].workout;
    responses = [{ content: bad }, { content: good }];
    const res = await request(app.app.getHttpServer())
      .post('/api/v1/generate-plan')
      .send(makeProfile())
      .expect(200);
    expect(res.body.source).toBe('groq');
    expect(observed[1].body.messages[0].content).toContain('days[2].workout');
    expect(observed[1].body.messages[0].content).toContain('REQUIRED');
  });

  it('preserves the BMR floor on repeated invalid AI output at a 944 kcal target', async () => {
    const profile = makeProfile({
      age: 65,
      height_cm: 150.4,
      weight_kg: 49,
      activity_level: ActivityLevel.SEDENTARY,
    });
    const bad = { days: (await samplePlan(profile)).days };
    for (const day of bad.days)
      for (const meal of day.meals) {
        meal.calories *= 0.8;
        meal.protein_g *= 0.8;
        meal.carbs_g *= 0.8;
        meal.fat_g *= 0.8;
      }
    responses = [{ content: bad }, { content: bad }];
    const res = await request(app.app.getHttpServer())
      .post('/api/v1/generate-plan')
      .send(profile)
      .expect(200);
    expect(res.body.source).toBe('sample');
    expect(res.body.daily_target.target_calories).toBe(944);
    expect(res.body.daily_target.bmr).toBe(944);
    expect(
      res.body.days.every(
        (d: any) =>
          d.meals.reduce((sum: number, m: any) => sum + m.calories, 0) >= 944,
      ),
    ).toBe(true);
    expect(observed).toHaveLength(2);
  });

  it('uses fallback after upstream 429 without another request', async () => {
    responses = [{ status: 429 }];
    const res = await request(app.app.getHttpServer())
      .post('/api/v1/generate-plan')
      .send(makeProfile())
      .expect(200);
    expect(res.body.source).toBe('sample');
    expect(observed).toHaveLength(1);
  });

  it('aborts a hanging real HTTP upstream and never retries timeout', async () => {
    responses = [{ hang: true }];
    const provider = new GroqPlanService(
      new ConfigService({
        PLAN_AI_PROVIDER: 'groq',
        GROQ_API_KEY: 'synthetic-http-key',
        GROQ_TIMEOUT_MS: '80',
        GROQ_TOTAL_TIMEOUT_MS: '80',
      }),
    );
    const result = await new PlanService(geminiOff, provider).generatePlan(
      makeProfile(),
    );
    expect(result.source).toBe('sample');
    expect(observed).toHaveLength(1);
    expect(JSON.stringify(warningCalls)).toContain('TIMEOUT');
  });
});

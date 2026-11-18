import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GroqPlanService } from './groq-plan.service.js';
import { PlanService } from './plan.service.js';
import { buildPlanPrompt, planPromptExample } from './gemini.service.js';
import { parsePlanContent } from './plan-validation.js';
import {
  planRepairInstructions,
  type PlanValidationIssue,
} from './plan-diagnostics.js';
import { computeDailyTarget } from './daily-target.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import {
  geminiOff,
  makeProfile,
  samplePlan,
} from '../../test/plan-fixtures.js';

const secret = 'SENSITIVE_SENTINEL_do_not_log';
const groq = (extra = {}) =>
  new GroqPlanService(
    new ConfigService({
      PLAN_AI_PROVIDER: 'groq',
      GROQ_API_KEY: secret,
      ...extra,
    }),
  );
const reply = (content: unknown) =>
  new Response(
    JSON.stringify({
      choices: [
        {
          finish_reason: 'stop',
          message: { content: JSON.stringify(content) },
        },
      ],
    }),
  );

describe('Groq failure diagnostics and bounded repair', () => {
  const warningCalls: unknown[][] = [];
  beforeEach(() => {
    warningCalls.length = 0;
    vi.spyOn(Logger.prototype, 'warn').mockImplementation(
      (...args: unknown[]) => {
        warningCalls.push(args);
      },
    );
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it.each([
    { target_calories: 944, bmr: 944 },
    { target_calories: 1624, bmr: 1399 },
    { target_calories: 2806, bmr: 1649 },
  ])(
    'prompt example satisfies cardinality, macros and BMR at $target_calories',
    (target) => {
      expect(
        parsePlanContent(planPromptExample(target.target_calories), target)
          .errors,
      ).toEqual([]);
    },
  );

  it('spells out the narrow range when the target is exactly the BMR floor', () => {
    const profile = makeProfile({
      age: 65,
      height_cm: 150.4,
      weight_kg: 49,
      activity_level: ActivityLevel.SEDENTARY,
    });
    const { target, flooredToBmr } = computeDailyTarget(profile);
    expect(flooredToBmr).toBe(true);
    expect(target.target_calories).toBe(944);
    const prompt = buildPlanPrompt(profile, target);
    expect(prompt).toContain('Tổng calo mỗi ngày: 944–1038 kcal');
    expect(prompt).toContain(
      'breakfast 142–330, lunch 236–425, dinner 236–425',
    );
    expect(prompt).toContain('breakfast 236, lunch 378, dinner 330');
  });

  it.each([
    [
      'missing name',
      (p: any) => {
        delete p.days[0].meals[0].name;
      },
      'REQUIRED',
      'days[0].meals[0].name',
    ],
    [
      'string calories',
      (p: any) => {
        p.days[0].meals[0].calories = secret;
      },
      'TYPE',
      'days[0].meals[0].calories',
    ],
    [
      'wrong enum',
      (p: any) => {
        p.days[0].meals[0].meal_type = secret;
      },
      'ENUM',
      'days[0].meals[0].meal_type',
    ],
    [
      'missing workout',
      (p: any) => {
        delete p.days[0].workout;
      },
      'REQUIRED',
      'days[0].workout',
    ],
    [
      'wrong cardinality',
      (p: any) => {
        p.days.pop();
      },
      'ARRAY_SIZE',
      'days',
    ],
    [
      'macro mismatch',
      (p: any) => {
        p.days[0].meals[0].protein_g = 999;
      },
      'MACRO_CALORIES',
      'days[0].meals[0]',
    ],
    [
      'duplicate name',
      (p: any) => {
        p.days[2].meals[2].name = p.days[0].meals[0].name;
      },
      'DUPLICATE_MEAL',
      'days[2].meals[2].name',
    ],
  ])(
    'diagnoses %s without values or silent numeric coercion',
    async (_name, mutate, code, path) => {
      const sample = await samplePlan();
      const raw = JSON.parse(JSON.stringify({ days: sample.days }));
      mutate(raw);
      const result = parsePlanContent(raw, sample.daily_target);
      expect(result.plan).toBeNull();
      expect(result.issues).toContainEqual(
        expect.objectContaining({ code, path }),
      );
      expect(JSON.stringify(result.issues)).not.toContain(secret);
    },
  );

  it('does not normalize a numeric string into a valid model number', async () => {
    const sample = await samplePlan();
    const raw = JSON.parse(JSON.stringify({ days: sample.days }));
    raw.days[0].meals[0].calories = String(raw.days[0].meals[0].calories);
    expect(parsePlanContent(raw, sample.daily_target).issues).toContainEqual(
      expect.objectContaining({ code: 'TYPE' }),
    );
  });

  it.each([null, [], 'not an object'])(
    'rejects a non-object response %s',
    (value) => {
      expect(
        parsePlanContent(value, { target_calories: 944, bmr: 944 }).issues,
      ).toEqual([
        {
          validator: 'class-validator',
          kind: 'schema',
          code: 'JSON_OBJECT',
          path: '$',
        },
      ]);
    },
  );

  it('logs fixed code/path/attempt/provider/duration and caps attempts at two', async () => {
    const good = { days: (await samplePlan()).days };
    const bad = structuredClone(good);
    bad.days[2].meals[2].name = secret;
    bad.days[1].meals[1].name = secret;
    const wire = vi.fn().mockImplementation(async () => reply(bad));
    vi.stubGlobal('fetch', wire);
    const plan = await new PlanService(geminiOff, groq()).generatePlan(
      makeProfile({}, { health_conditions: secret }),
    );
    expect(plan.source).toBe('sample');
    expect(wire).toHaveBeenCalledTimes(2);
    const logs = warningCalls.map(([entry]) => String(entry));
    expect(logs.join('\n')).not.toContain(secret);
    expect(logs.join('\n')).not.toContain('Authorization');
    const event = JSON.parse(
      logs.find((line) => line.includes('plan_validation_failed'))!,
    );
    expect(event).toMatchObject({
      provider: 'groq',
      attempt: 1,
      elapsed_ms: expect.any(Number),
      issues: [
        expect.objectContaining({
          code: 'DUPLICATE_MEAL',
          path: 'days[2].meals[2].name',
        }),
      ],
    });
    const second = JSON.parse(wire.mock.calls[1][1].body).messages[0]
      .content as string;
    const feedback = second.split('<plan_validation_feedback>')[1];
    expect(feedback).toContain('DUPLICATE_MEAL');
    expect(feedback).not.toContain(secret);
  });

  it('filters malformed diagnostic text instead of echoing it into a repair prompt', () => {
    const prompt = planRepairInstructions([
      {
        validator: secret,
        kind: secret,
        code: secret,
        path: secret,
      } as unknown as PlanValidationIssue,
    ]);
    expect(prompt).not.toContain(secret);
    expect(prompt).toContain('"path":"$"');
    expect(planRepairInstructions([])).toBe('');
  });

  it('does not echo exceptions, provider response bodies, or exception names', async () => {
    const error = new Error(secret);
    error.name = secret;
    const wire = vi.fn().mockRejectedValue(error);
    vi.stubGlobal('fetch', wire);
    expect(
      (await new PlanService(geminiOff, groq()).generatePlan(makeProfile()))
        .source,
    ).toBe('sample');
    expect(wire).toHaveBeenCalledTimes(2);
    expect(JSON.stringify(warningCalls)).not.toContain(secret);
  });

  it.each(['not JSON', 'truncated'])(
    'repairs %s with an output-level code and still validates the next response',
    async (kind) => {
      const good = { days: (await samplePlan()).days };
      const wire = vi
        .fn()
        .mockResolvedValueOnce(
          new Response(
            JSON.stringify({
              choices: [
                {
                  finish_reason: kind === 'truncated' ? 'length' : 'stop',
                  message: { content: secret },
                },
              ],
            }),
          ),
        )
        .mockResolvedValueOnce(reply(good));
      vi.stubGlobal('fetch', wire);
      expect(
        (await new PlanService(geminiOff, groq()).generatePlan(makeProfile()))
          .source,
      ).toBe('groq');
      const second = JSON.parse(wire.mock.calls[1][1].body).messages[0].content;
      expect(second).toContain(
        kind === 'truncated' ? 'INCOMPLETE_OUTPUT' : 'INVALID_JSON',
      );
      expect(second).not.toContain(secret);
    },
  );

  it('does not start a second request when the remaining total budget is too short', async () => {
    let now = 0;
    vi.spyOn(Date, 'now').mockImplementation(() => now);
    const wire = vi.fn().mockImplementation(async () => {
      now = 89000;
      return reply({ days: [] });
    });
    vi.stubGlobal('fetch', wire);
    expect(
      (await new PlanService(geminiOff, groq()).generatePlan(makeProfile()))
        .source,
    ).toBe('sample');
    expect(wire).toHaveBeenCalledTimes(1);
  });

  it('keeps recognised allergies and injuries during validation repair', async () => {
    const profile = makeProfile(
      {},
      { allergies: 'Trứng', injuries: 'Đầu gối' },
    );
    const safe = { days: (await samplePlan(profile)).days };
    const bad = structuredClone(safe);
    bad.days[0].meals[0].ingredients[0].name = 'Trứng';
    bad.days[0].workout.exercises[0].tags = ['kneeling' as any];
    const wire = vi
      .fn()
      .mockResolvedValueOnce(reply(bad))
      .mockResolvedValueOnce(reply(safe));
    vi.stubGlobal('fetch', wire);
    const result = await new PlanService(geminiOff, groq()).generatePlan(
      profile,
    );
    expect(result.source).toBe('groq');
    const second = JSON.parse(wire.mock.calls[1][1].body).messages[0]
      .content as string;
    expect(second).toContain('RESTRICTION_CONFLICT');
    expect(second).toContain('days[0].meals[0]');
    expect(result.days[0].workout.exercises[0].tags).not.toContain('kneeling');
    expect(second).toContain('Trứng');
    expect(second).toContain('kneeling');
    expect(JSON.stringify(warningCalls)).not.toContain('Trứng');
    // Enum tags are safe diagnostic metadata; raw allergy/profile text stays excluded.
  });
});

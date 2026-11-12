import { ConfigService } from '@nestjs/config';
import { GroqPlanService } from './groq-plan.service.js';
import { PlanService } from './plan.service.js';
import { buildPlanPrompt } from './gemini.service.js';
import { computeDailyTarget } from './daily-target.js';
import { parsePlanContent } from './plan-validation.js';
import {
  geminiOff,
  makeProfile,
  samplePlan,
} from '../../test/plan-fixtures.js';

describe('Groq validation regression: prompt, parser and repair', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('the JSON shape in the prompt satisfies its own three-day contract', () => {
    const profile = makeProfile();
    const { target } = computeDailyTarget(profile);
    const example = JSON.parse(
      buildPlanPrompt(profile, target).split('\n').at(-1)!,
    );
    expect(parsePlanContent(example, target).errors).toEqual([]);
  });

  it('spells out the same macro denominator as the actual validator', () => {
    const { target } = computeDailyTarget(makeProfile());
    expect(buildPlanPrompt(makeProfile(), target)).toContain(
      'abs(calories - (4*protein_g + 4*carbs_g + 9*fat_g)) <= 0.15*calories',
    );
  });

  it('rejects a missing required workout before restriction checks can crash', async () => {
    const content = await samplePlan();
    const raw = JSON.parse(JSON.stringify({ days: content.days }));
    delete raw.days[0].workout;
    expect(parsePlanContent(raw, content.daily_target).plan).toBeNull();
  });

  it('sends validation feedback on retry instead of repeating an identical prompt', async () => {
    const profile = makeProfile();
    const good = { days: (await samplePlan(profile)).days };
    const bad = structuredClone(good);
    bad.days[0].meals[0].calories = 9999;
    const reply = (value: unknown) =>
      new Response(
        JSON.stringify({
          choices: [
            {
              finish_reason: 'stop',
              message: { content: JSON.stringify(value) },
            },
          ],
        }),
      );
    const wire = vi
      .fn()
      .mockResolvedValueOnce(reply(bad))
      .mockResolvedValueOnce(reply(good));
    vi.stubGlobal('fetch', wire);
    const groq = new GroqPlanService(
      new ConfigService({
        PLAN_AI_PROVIDER: 'groq',
        GROQ_API_KEY: 'synthetic-key',
      }),
    );
    const result = await new PlanService(geminiOff, groq).generatePlan(profile);
    expect(result.source).toBe('groq');
    const first = JSON.parse(wire.mock.calls[0][1].body).messages[0].content;
    const second = JSON.parse(wire.mock.calls[1][1].body).messages[0].content;
    expect(second).not.toBe(first);
    expect(second).toContain('MEAL_CALORIES');
    expect(second).toContain('days[0].meals[0].calories');
  });
});

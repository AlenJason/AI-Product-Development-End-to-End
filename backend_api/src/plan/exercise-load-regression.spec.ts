import { readFileSync } from 'node:fs';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { assessedExercise, prepareAiPlanExercises } from './ai-exercise.js';
import {
  inferredLoads,
  type ExerciseDiagnostic,
} from './exercise-verification.js';
import { makeProfile, samplePlan } from '../../test/plan-fixtures.js';
import { Goal } from './enums/goal.enum.js';
import { GroqPlanService } from './groq-plan.service.js';
import { PlanService } from './plan.service.js';
import { findRestrictionViolations } from './restriction-filter.js';
import { matchRestrictions } from './restriction-matcher.js';
import type { PlanContentDto } from './dto/plan-content.dto.js';
const recorded = JSON.parse(
  readFileSync(
    new URL(
      '../../test/fixtures/groq-exercise-load-conflicts.json',
      import.meta.url,
    ),
    'utf8',
  ),
) as { days: { workout: { exercises: Record<string, unknown>[] } }[] }[];
const profile = makeProfile({ age: 65, goal: Goal.MAINTAIN });
describe('Sanitized real Groq exercise responses, HTTP200', () => {
  it('unrepairable verification failure is reported as validation with location and bounded repair', async () => {
    const base = await samplePlan(profile),
      bad = structuredClone(base) as unknown as {
        days: { workout: { exercises: unknown[] } }[];
      };
    bad.days[0].workout.exercises[0] = {
      name: 'private-health-name',
      muscle_group: 'private-health-value',
      tags: [],
      sets: 2,
      reps_or_duration: '10 lần',
      assessment: {
        difficulty_level: 1,
        equipment: 'none',
        impact: 'low',
        instructions: 'private instructions with personal text',
      },
    };
    const response = (value: unknown) =>
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
      .mockResolvedValueOnce(response(bad))
      .mockResolvedValueOnce(response(base));
    vi.stubGlobal('fetch', wire);
    const logs: unknown[] = [];
    vi.spyOn(Logger.prototype, 'warn').mockImplementation((v) => {
      logs.push(v);
    });
    const groq = new GroqPlanService(
      new ConfigService({
        PLAN_AI_PROVIDER: 'groq',
        GROQ_API_KEY: 'synthetic-key',
        GROQ_DEBUG_RESPONSES: 'false',
      }),
    );
    const result = await new PlanService(groq, groq).generatePlan(profile);
    expect(result.source).toBe('groq');
    expect(wire).toHaveBeenCalledTimes(2);
    const text = JSON.stringify(logs);
    expect(text).toContain('plan_validation_failed');
    expect(text).toContain('day_index');
    expect(text).not.toContain('TRANSPORT_OR_INTERNAL_ERROR');
    expect(text).not.toContain('private-health');
    const retry = JSON.parse(wire.mock.calls[1][1].body).messages[0].content;
    expect(retry).toContain('EXERCISE_VERIFICATION');
    expect(retry).toContain('days[0].workout.exercises[0]');
    expect(retry).not.toContain('private-health');
  });
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });
  it('reproduces the precise legacy first failures at day0/exercise1 and day0/exercise2', () => {
    const first = recorded[0].days[0].workout.exercises[1],
      second = recorded[1].days[0].workout.exercises[2];
    expect(first.name).toBe('Plank tường');
    expect(first.tags).toEqual([]);
    expect(second.name).toBe('Plank khuỷu tay');
    expect(second.tags).toEqual(['kneeling']);
    // The previous generic /plank/ rule demanded wrist_load for both identities.
    expect(/plank/iu.test(String(first.name))).toBe(true);
    expect(/plank/iu.test(String(second.name))).toBe(true);
    expect(inferredLoads('Plank khuỷu tay')).not.toContain('wrist_load');
  });
  for (const [index, record] of recorded.entries()) {
    it(`normalizes complete recorded attempt ${index + 1}, without trusting self-assessment`, () => {
      const before = structuredClone(record),
        notes: ExerciseDiagnostic[] = [];
      const normalized = prepareAiPlanExercises(record, profile, (d) =>
        notes.push(d),
      ) as typeof record;
      expect(normalized.days).toHaveLength(3);
      expect(record).toEqual(before);
      for (const day of normalized.days)
        for (const e of day.workout.exercises) {
          expect(() => assessedExercise(e, profile)).not.toThrow();
          expect(e).not.toHaveProperty('assessment');
        }
      expect(notes.some((d) => d.action === 'replaced')).toBe(true);
      expect(
        notes.every(
          (d) =>
            d.day_index >= 0 &&
            d.exercise_index >= 0 &&
            d.violated_rule &&
            d.error_code,
        ),
      ).toBe(true);
      expect(
        findRestrictionViolations(
          normalized.days.map((day) => ({
            ...day,
            meals: [],
          })) as unknown as PlanContentDto['days'],
          matchRestrictions(profile.restrictions),
        ),
      ).toEqual([]);
    });
    it(`Generate HTTP client attempt ${index + 1}: keeps AI meals, diagnoses/replaces unsafe exercises, no whole sample fallback`, async () => {
      const base = await samplePlan(profile);
      const content = {
        days: base.days.map((day, i) => ({
          ...day,
          workout: {
            ...day.workout,
            exercises: record.days[i].workout.exercises,
          },
        })),
      };
      const wire = vi.fn().mockResolvedValue(
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
      );
      vi.stubGlobal('fetch', wire);
      const logs: unknown[] = [];
      vi.spyOn(Logger.prototype, 'warn').mockImplementation((v) => {
        logs.push(v);
      });
      const groq = new GroqPlanService(
        new ConfigService({
          PLAN_AI_PROVIDER: 'groq',
          GROQ_API_KEY: 'synthetic-key',
          GROQ_DEBUG_RESPONSES: 'false',
        }),
      );
      const result = await new PlanService(groq, groq).generatePlan(profile);
      expect(result.source).toBe('groq');
      expect(wire).toHaveBeenCalledTimes(1);
      expect(result.days.map((d) => d.meals)).toEqual(
        base.days.map((d) => d.meals),
      );
      expect(result.warnings.join()).toContain('đã được thay');
      const log = JSON.stringify(logs);
      expect(log).toContain('exercise_index');
      expect(log).toContain('violated_rule');
      expect(log).not.toContain('TRANSPORT_OR_INTERNAL_ERROR');
      expect(log).not.toContain('synthetic-key');
      expect(log).not.toContain('Plank tường');
    });
  }
  it('repairs wall push-up standing metadata instead of trusting kneeling tag', () => {
    const e = recorded[1].days[2].workout.exercises[1];
    const r = assessedExercise(e, profile);
    expect(r.value).toMatchObject({
      name: 'Chống đẩy tường',
      muscle_group: 'chest',
      tags: [],
    });
    expect(r.repair?.action).toBe('repaired');
  });
  it('cannot lower a reviewed forearm plank from level2 to level1 by model claim', () => {
    expect(() =>
      assessedExercise(recorded[1].days[0].workout.exercises[2], profile),
    ).toThrow('AI_EXERCISE_LEVEL_CONFLICT');
  });
  it('rejects standing/kneeling contradiction and prone Bird-dog before repair', () => {
    expect(() =>
      assessedExercise(recorded[0].days[1].workout.exercises[0], profile),
    ).toThrow('AI_EXERCISE_LOAD_CONFLICT');
    expect(() =>
      assessedExercise(recorded[1].days[2].workout.exercises[2], profile),
    ).toThrow('AI_EXERCISE_INSTRUCTION_CONFLICT');
  });
  it('does not repair excessive volume by changing declared difficulty', () => {
    expect(() =>
      assessedExercise(
        {
          name: 'Đi bộ tại chỗ',
          sets: 2,
          reps_or_duration: '500 phút',
          muscle_group: 'cardio',
          tags: [],
          assessment: { difficulty_level: 1, equipment: 'none', impact: 'low' },
        },
        profile,
      ),
    ).toThrow('AI_EXERCISE_VOLUME_CONFLICT');
  });
});

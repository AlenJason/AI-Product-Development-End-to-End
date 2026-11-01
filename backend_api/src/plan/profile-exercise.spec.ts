import { ConfigService } from '@nestjs/config';
import { assessedExercise, aiExerciseInstructions } from './ai-exercise.js';
import { buildPlanPrompt, userDataBlock } from './gemini.service.js';
import { profileAssessmentExample } from './profile-exercise.js';
import {
  makeProfile,
  samplePlan,
  firstPick,
} from '../../test/plan-fixtures.js';
import { PlanService } from './plan.service.js';
import { GroqPlanService } from './groq-plan.service.js';
import { ExerciseSwapService } from './adjust/exercise-swap.service.js';
import { SWAP_EXERCISES } from './swap-pools.js';
import { computeDailyTarget } from './daily-target.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import type { CreatePlanDto } from './dto/create-plan.dto.js';

function novel(profile: CreatePlanDto) {
  return {
    name: 'Đứng nâng mũi chân hai bên',
    sets: 2,
    reps_or_duration: '8 lần',
    muscle_group: 'legs',
    tags: [],
    assessment: {
      ...profileAssessmentExample(profile),
      instructions:
        'Đứng bằng hai chân, nhấc nhẹ hai mũi chân rồi hạ xuống chậm, không nhảy.',
      profile_fit: {
        ...profileAssessmentExample(profile).profile_fit,
        reason:
          'Chọn vận động đứng có nhịp chậm, xét tuổi và các hạn chế trong hồ sơ.',
      },
    },
  };
}
describe('AI exercise selection from profile without a closed name catalog', () => {
  afterEach(() => vi.unstubAllGlobals());
  it('sends age/body/activity/pregnancy and health restrictions as user data', () => {
    const p = makeProfile(
        { age: 65 },
        { health_conditions: 'tăng huyết áp', injuries: 'đau gối' },
      ),
      block = userDataBlock(p).join('\n');
    expect(block).toContain('"age":65');
    expect(block).toContain('"height_cm":168');
    expect(block).toContain('"activity_level":"light"');
    expect(block).toContain('tăng huyết áp');
    expect(block).toContain('đau gối');
    const prompt = buildPlanPrompt(p, computeDailyTarget(p).target);
    expect(prompt).toContain('profile_fit');
    expect(prompt).not.toContain('Metadata tham khảo từ dữ liệu dự án');
    expect(aiExerciseInstructions(p).join()).not.toContain('Chống đẩy tường');
    expect(aiExerciseInstructions(p).join()).not.toContain('Bird-dog');
  });
  it('accepts a new name with consistent movement and profile fields, without adding to JSON pool', () => {
    const p = makeProfile({ age: 65 }),
      exercise = novel(p),
      before = SWAP_EXERCISES.length;
    expect(SWAP_EXERCISES.some((e) => e.name === exercise.name)).toBe(false);
    const result = assessedExercise(exercise, p);
    expect(result.value).toMatchObject({ name: exercise.name, sets: 2 });
    expect(result.level).toBe(1);
    expect(result.repair?.action).toBe('assessed');
    expect(result.value).not.toHaveProperty('assessment');
    expect(SWAP_EXERCISES.length).toBe(before);
  });
  it('rejects a wrong age/activity context rather than applying someone else profile', () => {
    const p = makeProfile({ age: 65 }),
      exercise = novel(p);
    exercise.assessment.profile_fit.age = 22;
    expect(() => assessedExercise(exercise, p)).toThrow(
      'AI_EXERCISE_PROFILE_CONFLICT',
    );
  });
  it('cannot label wrist-supported movement as level1 for a capped profile', () => {
    const p = makeProfile({ age: 65 }),
      exercise = {
        ...novel(p),
        name: 'Chống bàn tay giữ người',
        tags: ['wrist_load'],
        assessment: {
          ...novel(p).assessment,
          instructions: 'Chống bàn tay xuống sàn và giữ thân người thẳng.',
          movement: {
            position: 'hand_support',
            balance: 'stable',
            tempo: 'controlled',
          },
        },
      };
    expect(() => assessedExercise(exercise, p)).toThrow(
      'AI_EXERCISE_LEVEL_CONFLICT',
    );
  });
  it('checks injuries from derived features even when the AI omits load tags', () => {
    const p = makeProfile(
        { age: 25, activity_level: ActivityLevel.ACTIVE },
        { injuries: 'đau gối' },
      ),
      exercise = {
        ...novel(p),
        name: 'Quỳ duỗi chân chậm',
        tags: [],
        assessment: {
          ...novel(p).assessment,
          instructions: 'Quỳ bốn điểm trên sàn và duỗi chân ra sau chậm.',
          movement: {
            position: 'quadruped',
            balance: 'stable',
            tempo: 'controlled',
          },
        },
      };
    expect(() => assessedExercise(exercise, p)).toThrow(
      'AI_EXERCISE_LOAD_CONFLICT',
    );
  });
  it.each([{ sets: 6 }, { reps_or_duration: '100 lần' }])(
    'rejects excessive workload %j',
    (change) => {
      const p = makeProfile({ age: 65 });
      expect(() => assessedExercise({ ...novel(p), ...change }, p)).toThrow(
        'AI_EXERCISE_VOLUME_CONFLICT',
      );
    },
  );
  it('rejects claimed standing movement whose description is on the floor', () => {
    const p = makeProfile({ age: 65 }),
      exercise = novel(p);
    exercise.assessment.instructions =
      'Nằm ngửa trên sàn và nâng hai chân lên chậm.';
    expect(() => assessedExercise(exercise, p)).toThrow(
      'AI_EXERCISE_INSTRUCTION_CONFLICT',
    );
  });
  it('generate keeps outside-pool AI exercises and strips private profile_fit from the public response', async () => {
    const p = makeProfile({ age: 65 }),
      base = await samplePlan(p),
      content = {
        days: base.days.map((d) => ({
          ...d,
          workout: { ...d.workout, exercises: [novel(p)] },
        })),
      };
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
                  message: { content: JSON.stringify(content) },
                },
              ],
            }),
          ),
        ),
    );
    const groq = new GroqPlanService(
      new ConfigService({
        PLAN_AI_PROVIDER: 'groq',
        GROQ_API_KEY: 'synthetic-key',
        GROQ_DEBUG_RESPONSES: 'false',
      }),
    );
    const result = await new PlanService(groq, groq).generatePlan(p);
    expect(result.source).toBe('groq');
    expect(
      result.days.every((d) => d.workout.exercises[0].name === novel(p).name),
    ).toBe(true);
    expect(result.warnings.join()).not.toContain('đã được thay');
    expect(JSON.stringify(result)).not.toContain('profile_fit');
  });
  it('swap accepts a profile-based proposal outside the catalog and keeps the existing plan contract', async () => {
    const p = makeProfile(),
      plan = await samplePlan(p),
      generateJson = vi.fn().mockResolvedValue(novel(p)),
      ai = {
        providerName: 'groq' as const,
        isConfigured: true,
        budget: { perCallMs: 7500, totalMs: 15000 },
        generateJson,
        generatePlanContent: vi.fn(),
      };
    const result = await new ExerciseSwapService(ai, firstPick).swap({
      profile: p,
      plan,
      exercise_id: 'e1_2',
    });
    expect(result.days[0].workout.exercises[1].name).toBe(novel(p).name);
    expect(generateJson).toHaveBeenCalledTimes(1);
    expect(result.warnings.join()).toContain('[AI:exercise-swap:groq]');
  });
});

import { ConfigService } from '@nestjs/config';
import { assessedExercise, prepareAiPlanExercises } from './ai-exercise.js';
import {
  inferredLoads,
  ExerciseValidationError,
} from './exercise-verification.js';
import {
  makeProfile,
  samplePlan,
  firstPick,
} from '../../test/plan-fixtures.js';
import { GroqPlanService } from './groq-plan.service.js';
import { PlanService } from './plan.service.js';
import { ExerciseSwapService } from './adjust/exercise-swap.service.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { Goal } from './enums/goal.enum.js';
const proposal = {
  name: 'wall push‑up',
  sets: 2,
  reps_or_duration: '8 lần',
  muscle_group: 'chest',
  tags: [],
  assessment: {
    difficulty_level: 1,
    equipment: 'none',
    impact: 'low',
    instructions: 'Đặt tay lên tường, nghiêng người rồi đẩy về vị trí bắt đầu.',
  },
};
describe('Independent exercise metadata verification', () => {
  it('known chair/bottle exercises cannot claim equipment none', () => {
    for (const name of ['Dip ghế (Bench dip)', 'Co tay với chai nước'])
      expect(() =>
        assessedExercise(
          {
            ...proposal,
            name,
            assessment: { ...proposal.assessment, equipment: 'none' },
          },
          makeProfile(),
        ),
      ).toThrow('AI_EXERCISE_EQUIPMENT_CONFLICT');
  });
  afterEach(() => vi.unstubAllGlobals());
  it('resolves a reviewed Unicode alias without trusting a model ID', () => {
    const r = assessedExercise(proposal, makeProfile());
    expect(r.level).toBe(1);
    expect(r.value).toMatchObject({ name: 'Chống đẩy tường', tags: [] });
    expect(r.value).not.toHaveProperty('assessment');
  });
  it.each([
    { muscle_group: 'back', tags: ['kneeling'] },
    {
      assessment: {
        ...proposal.assessment,
        difficulty_level: 3,
        impact: 'high',
        equipment: 'invalid',
      },
    },
  ])('repairs false metadata from verified identity %j', (change) => {
    const r = assessedExercise({ ...proposal, ...change }, makeProfile());
    expect(r.level).toBe(1);
    expect(r.repair?.action).toBe('repaired');
    expect(r.value).toMatchObject({ muscle_group: 'chest', tags: [] });
  });
  it.each([
    { age: 65, activity_level: ActivityLevel.ACTIVE, goal: Goal.MAINTAIN },
    { age: 48, activity_level: ActivityLevel.SEDENTARY, goal: Goal.MAINTAIN },
    { pregnant_or_breastfeeding: true, goal: Goal.MAINTAIN },
  ])('uses verified profile level cap %j', (p) => {
    expect(() => assessedExercise(proposal, makeProfile(p))).not.toThrow();
    expect(() =>
      assessedExercise(
        {
          ...proposal,
          name: 'Burpee',
          tags: [],
          assessment: { ...proposal.assessment, difficulty_level: 1 },
        },
        makeProfile(p),
      ),
    ).toThrow('AI_EXERCISE_LEVEL_CONFLICT');
  });
  it('active young user may use a verified level3 exercise', () => {
    expect(
      assessedExercise(
        {
          name: 'Burpee',
          sets: 2,
          reps_or_duration: '8 lần',
          muscle_group: 'full_body',
          tags: ['jumping', 'wrist_load'],
        },
        makeProfile({ age: 25, activity_level: ActivityLevel.ACTIVE }),
      ).level,
    ).toBe(3);
  });
  it.each([
    { sets: 6 },
    { reps_or_duration: '500 lần' },
    { reps_or_duration: 'tùy ý' },
  ])('rejects excessive/unparseable verified workload %j', (change) => {
    expect(() =>
      assessedExercise({ ...proposal, ...change }, makeProfile()),
    ).toThrow('AI_EXERCISE_VOLUME_CONFLICT');
  });
  it('does not trust a new exercise just because AI claims safe metadata', () => {
    expect(() =>
      assessedExercise(
        { ...proposal, name: 'Đứng đưa chân sang ngang chậm' },
        makeProfile(),
      ),
    ).toThrow('AI_EXERCISE_ASSESSMENT_INVALID');
  });
  it('equipment in instructions cannot be removed by claiming equipment none', () => {
    expect(() =>
      assessedExercise(
        {
          ...proposal,
          assessment: {
            ...proposal.assessment,
            instructions: 'Đứng tập với dumbbell, nâng tạ lên trước mặt.',
          },
        },
        makeProfile(),
      ),
    ).toThrow('AI_EXERCISE_EQUIPMENT_CONFLICT');
  });
  it('verified injury tags cannot be removed by the model', () => {
    expect(() =>
      assessedExercise(
        {
          name: 'Bird-dog',
          sets: 2,
          reps_or_duration: '8 lần',
          muscle_group: 'core',
          tags: [],
        },
        makeProfile({}, { injuries: 'đau gối' }),
      ),
    ).toThrow('AI_EXERCISE_LOAD_CONFLICT');
  });
  it('does not mistake negation or forearm support for jumping or wrist support', () => {
    expect(inferredLoads('Đi bộ, không nhảy. Không bật nhảy.')).not.toContain(
      'jumping',
    );
    expect(inferredLoads('Không nhảy, sau đó nhảy lên.')).toContain('jumping');
    expect(
      inferredLoads('Plank khuỷu tay, đặt khuỷu tay dưới vai.'),
    ).not.toContain('wrist_load');
  });
  it('contradictory Bird-dog prone instructions cannot be metadata-repaired', () => {
    expect(() =>
      assessedExercise(
        {
          name: 'Bird‑dog trên sàn',
          sets: 2,
          reps_or_duration: '8 lần',
          muscle_group: 'core',
          tags: [],
          assessment: {
            instructions: 'Nằm sấp, nâng tay và chân đối diện lên.',
          },
        },
        makeProfile(),
      ),
    ).toThrow('AI_EXERCISE_INSTRUCTION_CONFLICT');
  });
  it('generate preserves verified AI alias, strips assessment and leaves source truthful', async () => {
    const p = makeProfile({ age: 65, goal: Goal.MAINTAIN }),
      sample = await samplePlan(p);
    const content = {
      days: sample.days.map((d) => ({
        ...d,
        workout: { ...d.workout, exercises: [proposal] },
      })),
    };
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
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
      }),
    );
    const plan = await new PlanService(groq, groq).generatePlan(p);
    expect(plan.source).toBe('groq');
    expect(
      plan.days.every((d) => d.workout.exercises[0].name === 'Chống đẩy tường'),
    ).toBe(true);
    expect(JSON.stringify(plan)).not.toContain('assessment');
  });
  it('swap uses verified aliases with existing contract and IDs', async () => {
    const profile = makeProfile(),
      plan = await samplePlan(profile),
      generateJson = vi.fn().mockResolvedValue(proposal);
    const ai = {
      providerName: 'groq' as const,
      isConfigured: true,
      budget: { perCallMs: 7500, totalMs: 15000 },
      generateJson,
      generatePlanContent: vi.fn(),
    };
    const result = await new ExerciseSwapService(ai, firstPick).swap({
      profile,
      plan,
      exercise_id: 'e1_3',
    });
    expect(result.days[0].workout.exercises[2]).toMatchObject({
      name: 'Chống đẩy tường',
      exercise_id: 'e1_3',
    });
    expect(generateJson).toHaveBeenCalledTimes(1);
  });
  it('error diagnostics never include untrusted names or health text', () => {
    try {
      assessedExercise(
        { ...proposal, name: 'secret-profile nhảy', tags: [] },
        makeProfile(),
      );
      throw new Error('expected failure');
    } catch (e) {
      expect(e).toBeInstanceOf(ExerciseValidationError);
      expect(
        JSON.stringify((e as ExerciseValidationError).diagnostic()),
      ).not.toContain('secret-profile');
    }
  });
  it('normalization does not mutate invalid input', () => {
    const raw = { days: [{ workout: { exercises: [{ name: 'unknown' }] } }] },
      before = structuredClone(raw);
    expect(() => prepareAiPlanExercises(raw, makeProfile())).toThrow();
    expect(raw).toEqual(before);
  });
});

import { Logger, UnprocessableEntityException } from '@nestjs/common';
import {
  firstPick,
  geminiOff,
  makeProfile,
  samplePlan,
} from '../../../test/plan-fixtures.js';
import type { PlanAi } from '../ai-provider.js';
import { GroqRequestError } from '../groq-plan.service.js';
import { MealSwapService } from './meal-swap.service.js';
import { ExerciseSwapService } from './exercise-swap.service.js';
import { FeedbackService } from './feedback.service.js';
import { PlanService } from '../plan.service.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import type { FeedbackDto } from '../dto/adjust-plan.dto.js';
import * as pools from '../swap-pools.js';

const exercise = {
  name: 'Cầu mông (Glute bridge)',
  sets: 2,
  reps_or_duration: '10 lần',
  muscle_group: 'legs',
  tags: [],
};
function ai(answer: unknown): PlanAi {
  return {
    providerName: 'groq',
    isConfigured: true,
    budget: { perCallMs: 7500, totalMs: 15000 },
    generatePlanContent: vi.fn(),
    generateJson:
      answer instanceof Error
        ? vi.fn().mockRejectedValue(answer)
        : vi.fn().mockResolvedValue(answer),
  };
}
describe('Groq adjustment validation, failure and deduplication', () => {
  let plan: MealPlanResponseDto;
  const profile = makeProfile();
  beforeAll(async () => {
    plan = await samplePlan(profile);
  });
  afterEach(() => vi.restoreAllMocks());
  const request = (overrides: Partial<FeedbackDto> = {}): FeedbackDto => ({
    profile,
    plan,
    day_number: 1,
    intensity: Intensity.MODERATE,
    body_states: [BodyState.NORMAL],
    eating: Eating.UNDER,
    ...overrides,
  });
  it('accepts reviewed lighter Groq exercise and identifies action source', async () => {
    const provider = ai(exercise);
    const before = structuredClone(plan);
    const result = await new ExerciseSwapService(provider, firstPick).swap({
      profile,
      plan,
      exercise_id: 'e1_2',
    });
    expect(result.days[0].workout.exercises[1].name).toBe(exercise.name);
    expect(result.warnings.join()).toContain('[AI:exercise-swap:groq]');
    expect(result.source).toBe(plan.source);
    expect(plan).toEqual(before);
  });
  it.each([{ muscle_group: 'chest' }, { tags: ['jumping'] }])(
    'uses verified metadata instead of false claims %j',
    async (change) => {
      const provider = ai({ ...exercise, ...change });
      const result = await new ExerciseSwapService(provider, firstPick).swap({
        profile,
        plan,
        exercise_id: 'e1_2',
      });
      expect(provider.generateJson).toHaveBeenCalledTimes(1);
      expect(result.days[0].workout.exercises[1]).toMatchObject({
        name: exercise.name,
        muscle_group: 'legs',
        tags: [],
      });
    },
  );
  it.each([
    { name: 'Bài máy tập chưa xác minh' },
    { name: 'Squat nhảy', tags: [] },
    { reps_or_duration: '100 lần' },
    { reps_or_duration: 'tập tùy thích' },
    { sets: 6 },

    { name: 'Squat tay không' },
  ])(
    'rejects unsafe/unverified replacement %j before using validated fallback',
    async (change) => {
      const provider = ai({ ...exercise, ...change });
      const result = await new ExerciseSwapService(provider, firstPick).swap({
        profile,
        plan,
        exercise_id: 'e1_2',
      });
      expect(provider.generateJson).toHaveBeenCalledTimes(2);
      expect(result.warnings.join()).toContain('[AI:exercise-swap:fallback]');
      expect(
        pools.exerciseLevel(result.days[0].workout.exercises[1].name),
      ).toBe(1);
    },
  );
  it('does not accept malformed fallback metadata', async () => {
    const invalid = {
      ...pools.SWAP_EXERCISES.find((e) => e.name === 'Squat nhảy')!,
      level: 1 as const,
    };
    vi.spyOn(pools, 'exerciseCandidates').mockReturnValue([invalid]);
    const provider = { ...ai(null), isConfigured: false };
    await expect(
      new ExerciseSwapService(provider, firstPick).swap({
        profile,
        plan,
        exercise_id: 'e1_2',
      }),
    ).rejects.toBeInstanceOf(UnprocessableEntityException);
  });
  it.each([
    new GroqRequestError(429),
    Object.assign(new Error('private'), { name: 'TimeoutError' }),
  ])(
    'timeout/rate limit fall back with a single provider request',
    async (error) => {
      const provider = ai(error);
      const result = await new ExerciseSwapService(provider, firstPick).swap({
        profile,
        plan,
        exercise_id: 'e1_2',
      });
      expect(provider.generateJson).toHaveBeenCalledTimes(1);
      expect(result.warnings.join()).toContain(':fallback]');
    },
  );
  it('accepts valid Groq meal, rebuilds grocery, preserves input', async () => {
    const meal = { ...plan.days[0].meals[1], name: 'Cơm gà rau củ mới' };
    const provider = ai(meal);
    const before = structuredClone(plan);
    const result = await new MealSwapService(provider, firstPick).swap({
      profile,
      plan,
      meal_id: 'm1_2',
    });
    expect(result.warnings.join()).toContain('[AI:meal-swap:groq]');
    expect(result.grocery_list.length).toBeGreaterThan(0);
    expect(plan).toEqual(before);
  });
  it('allergen cannot bypass validation via Groq or exhausted fallback', async () => {
    const restricted = makeProfile(
      {},
      { allergies: 'hải sản, thịt bò, đậu phụ, thịt heo, gà' },
    );
    const provider = ai({
      ...plan.days[0].meals[1],
      name: 'Món mới',
      ingredients: [
        { name: 'Tôm', amount: 100, unit: 'g', category: 'protein' },
      ],
    });
    const before = structuredClone(plan);
    await expect(
      new MealSwapService(provider, firstPick).swap({
        profile: restricted,
        plan,
        meal_id: 'm1_2',
      }),
    ).rejects.toBeInstanceOf(UnprocessableEntityException);
    expect(plan).toEqual(before);
  });
  it('concurrent and repeated identical feedback uses one AI result; cached result cannot be mutated', async () => {
    const meals = plan.days[1].meals.map((m, i) => ({
      ...m,
      name: `Món cân đối mới ${i}`,
    }));
    const provider = ai({ meals });
    const service = new FeedbackService(provider, new PlanService(geminiOff));
    const [one, two] = await Promise.all([
      service.apply(request()),
      service.apply(request()),
    ]);
    expect(provider.generateJson).toHaveBeenCalledTimes(1);
    expect(one).toEqual(two);
    expect(one.response.plan.warnings.join()).toContain(
      '[AI:feedback-meals:groq]',
    );
    one.response.plan.days[1].meals[0].name = 'mutation';
    const third = await service.apply(request());
    expect(third.response.plan.days[1].meals[0].name).toBe(meals[0].name);
    expect(provider.generateJson).toHaveBeenCalledTimes(1);
  });
  it('failed rebalancing keeps meals and current day, with controlled rule-based fallback', async () => {
    const provider = ai(new GroqRequestError(429));
    const before = structuredClone(plan);
    const result = await new FeedbackService(
      provider,
      new PlanService(geminiOff),
    ).apply(request());
    expect(result.response.plan.days[0]).toEqual(plan.days[0]);
    expect(result.response.plan.days[1].meals).toEqual(plan.days[1].meals);
    expect(plan).toEqual(before);
    expect(result.response.plan.warnings.join()).toContain(
      '[AI:feedback-meals:fallback]',
    );
  });
  it('failed Groq day3 generation cannot replace old cycle, failed request is retryable', async () => {
    const provider = ai(null),
      plans = new PlanService(geminiOff);
    const generate = vi.spyOn(plans, 'generatePlan').mockResolvedValue(plan);
    const service = new FeedbackService(provider, plans);
    await expect(
      service.apply(request({ day_number: 3 })),
    ).rejects.toBeInstanceOf(UnprocessableEntityException);
    await expect(
      service.apply(request({ day_number: 3 })),
    ).rejects.toBeInstanceOf(UnprocessableEntityException);
    expect(generate).toHaveBeenCalledTimes(2);
  });
  it('danger signs bypass AI', async () => {
    const provider = ai(null);
    const result = await new FeedbackService(
      provider,
      new PlanService(geminiOff),
    ).apply(request({ body_states: [BodyState.DANGER_SIGN] }));
    expect(provider.generateJson).not.toHaveBeenCalled();
    expect(result.response.safety_warning).not.toBeNull();
  });
  it('Groq diagnostics cannot echo key, prompt or provider error text', async () => {
    const warn = vi
        .spyOn(Logger.prototype, 'warn')
        .mockImplementation(() => {}),
      error = vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
    const provider = ai(new Error('synthetic-secret-key/private-profile'));
    await new ExerciseSwapService(provider, firstPick).swap({
      profile,
      plan,
      exercise_id: 'e1_2',
    });
    const logs = JSON.stringify([warn.mock.calls, error.mock.calls]);
    expect(logs).not.toContain('synthetic-secret-key');
    expect(logs).not.toContain('private-profile');
    expect(logs).toContain('fallback');
  });
});

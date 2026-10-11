import { UnprocessableEntityException } from '@nestjs/common';
import { firstPick, geminiAnswering, geminiOff, makeProfile, samplePlan } from '../../../test/plan-fixtures.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { ExerciseTag } from '../enums/exercise.enum.js';
import { exerciseLevel } from '../swap-pools.js';
import { ExerciseSwapService } from './exercise-swap.service.js';

describe('ExerciseSwapService', () => {
  let plan: MealPlanResponseDto;

  beforeAll(async () => {
    plan = await samplePlan();
  });

  const swap = (service: ExerciseSwapService, exerciseId: string, profile = makeProfile()) =>
    service.swap({ profile, plan, exercise_id: exerciseId });

  describe('without Gemini (pool)', () => {
    it('chooses a lighter exercise in the same muscle group and preserves the rest of the plan', async () => {
      const swapped = await swap(new ExerciseSwapService(geminiOff, firstPick), 'e1_2');
      const before = plan.days[0].workout.exercises[1];
      const after = swapped.days[0].workout.exercises[1];

      expect(before.name).toBe('Squat tay không');
      expect(after).toMatchObject({ exercise_id: 'e1_2', muscle_group: 'legs' });
      expect(exerciseLevel(after.name)).toBeLessThan(exerciseLevel(before.name) ?? 0);
      expect(after.sets).toBeLessThanOrEqual(before.sets);
      expect(swapped.plan_id).toBe(plan.plan_id);
      expect(swapped.days[0].meals).toEqual(plan.days[0].meals);
    });

    it('returns 422 if the exercise is already the lightest in its group', async () => {
      await expect(swap(new ExerciseSwapService(geminiOff, firstPick), 'e3_2')).rejects.toBeInstanceOf(
        UnprocessableEntityException,
      );
    });

    it('filters exercises that load a declared injury', async () => {
      const swapped = await swap(
        new ExerciseSwapService(geminiOff, firstPick),
        'e1_1',
        makeProfile({}, { injuries: 'đau gối' }),
      );
      expect(swapped.days[0].workout.exercises[0].tags).not.toContain(ExerciseTag.JUMPING);
    });
  });

  describe('with Gemini', () => {
    const lighterSquat = (overrides: object = {}) => ({
      name: 'Squat nửa biên độ dựa ghế',
      sets: 2,
      reps_or_duration: '10 lần',
      muscle_group: 'legs',
      tags: [],
      ...overrides,
    });

    it('accepts a Gemini exercise that passes all measurable checks', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterSquat());
      const swapped = await swap(new ExerciseSwapService(gemini, firstPick), 'e1_2');
      expect(generateJson).toHaveBeenCalledTimes(1);
      expect(swapped.days[0].workout.exercises[1]).toMatchObject({ name: 'Squat nửa biên độ dựa ghế', sets: 2 });
    });

    it.each([
      ['a different muscle group', lighterSquat({ muscle_group: 'chest' })],
      ['more sets than the original', lighterSquat({ sets: 5 })],
      ['an additional load tag', lighterSquat({ tags: ['jumping'] })],
      ['an exercise already in the workout', lighterSquat({ name: 'Plank cẳng tay' })],
    ])('rejects %s and falls back to the pool', async (_label, invalid) => {
      const { gemini, generateJson } = geminiAnswering(invalid, invalid);
      const swapped = await swap(new ExerciseSwapService(gemini, firstPick), 'e1_2');
      expect(generateJson).toHaveBeenCalledTimes(2);
      expect(exerciseLevel(swapped.days[0].workout.exercises[1].name)).toBe(1);
    });
  });
});

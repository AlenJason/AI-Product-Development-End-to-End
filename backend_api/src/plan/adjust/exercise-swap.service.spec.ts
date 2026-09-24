import { UnprocessableEntityException } from '@nestjs/common';
import { firstPick, geminiAnswering, geminiOff, makeProfile, samplePlan } from '../../../test/plan-fixtures.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { ExerciseTag } from '../enums/exercise.enum.js';
import { exerciseLevel } from '../swap-pools.js';
import { ExerciseSwapService } from './exercise-swap.service.js';

// Plan mẫu không hạn chế: e1_2 = "Squat tay không" (legs, mức 2, 3 hiệp); e3_2 = "Chống đẩy tường" (chest, mức 1).
describe('ExerciseSwapService', () => {
  let plan: MealPlanResponseDto;

  beforeAll(async () => {
    plan = await samplePlan();
  });

  const swap = (service: ExerciseSwapService, exerciseId: string, profile = makeProfile()) =>
    service.swap({ profile, plan, exercise_id: exerciseId });

  describe('without Gemini (pool)', () => {
    it('picks a lighter exercise for the same muscle group and keeps everything else', async () => {
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

    it('answers 422 when the exercise is already the lightest of its group', async () => {
      await expect(swap(new ExerciseSwapService(geminiOff, firstPick), 'e3_2')).rejects.toBeInstanceOf(UnprocessableEntityException);
    });

    it('never picks an exercise that loads a declared injury', async () => {
      const swapped = await swap(new ExerciseSwapService(geminiOff, firstPick), 'e1_1', makeProfile({}, { injuries: 'đau gối' }));
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

    it('uses a Gemini exercise that passes the measurable "lighter" checks', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterSquat());
      const swapped = await swap(new ExerciseSwapService(gemini, firstPick), 'e1_2');
      expect(generateJson).toHaveBeenCalledTimes(1);
      expect(swapped.days[0].workout.exercises[1]).toMatchObject({ name: 'Squat nửa biên độ dựa ghế', sets: 2 });
    });

    it.each([
      ['another muscle group', lighterSquat({ muscle_group: 'chest' })],
      ['more sets than before', lighterSquat({ sets: 5 })],
      ['a new kind of load', lighterSquat({ tags: ['jumping'] })],
      ['an exercise already in the session', lighterSquat({ name: 'Plank cẳng tay' })],
    ])('rejects %s, then falls back to the pool', async (_label, bad) => {
      const { gemini, generateJson } = geminiAnswering(bad, bad);
      const swapped = await swap(new ExerciseSwapService(gemini, firstPick), 'e1_2');
      expect(generateJson).toHaveBeenCalledTimes(2);
      expect(exerciseLevel(swapped.days[0].workout.exercises[1].name)).toBe(1);
    });
  });
});

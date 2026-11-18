import {
  geminiAnswering,
  geminiOff,
  makeProfile,
  samplePlan,
} from '../../../test/plan-fixtures.js';
import type { FeedbackDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import { REST_WORKOUT } from '../exercise-presets.js';
import type { GeminiService } from '../gemini.service.js';
import { PlanService } from '../plan.service.js';
import { SAFETY_WARNING_MESSAGE, WARNINGS } from '../plan-warnings.js';
import { FeedbackService } from './feedback.service.js';

const macros = (calories: number) => ({
  protein_g: (calories * 0.25) / 4,
  carbs_g: (calories * 0.5) / 4,
  fat_g: (calories * 0.25) / 9,
});
const meals = (breakfast: number, lunch: number, dinner: number) => ({
  meals: [
    {
      meal_type: 'breakfast',
      name: 'Cháo yến mạch táo',
      portion: '1 bát',
      calories: breakfast,
      ...macros(breakfast),
      ingredients: [
        { name: 'Yến mạch', amount: 50, unit: 'g', category: 'pantry' },
      ],
    },
    {
      meal_type: 'lunch',
      name: 'Cơm gạo lứt, gà hấp gừng',
      portion: '1 chén + 1 đĩa',
      calories: lunch,
      ...macros(lunch),
      ingredients: [
        { name: 'Gạo lứt', amount: 90, unit: 'g', category: 'pantry' },
      ],
    },
    {
      meal_type: 'dinner',
      name: 'Canh rau củ đậu phụ non',
      portion: '1 bát + 1 chén cơm',
      calories: dinner,
      ...macros(dinner),
      ingredients: [
        { name: 'Đậu phụ non', amount: 150, unit: 'g', category: 'protein' },
      ],
    },
  ],
});
const lighterDay = () => meals(360, 560, 540);

describe('FeedbackService', () => {
  let plan: MealPlanResponseDto;

  beforeAll(async () => {
    plan = await samplePlan();
  });

  afterEach(() => vi.restoreAllMocks());

  const service = (
    gemini: GeminiService = geminiOff,
    planService = new PlanService(geminiOff),
  ) => new FeedbackService(gemini, planService);
  const request = (overrides: Partial<FeedbackDto> = {}): FeedbackDto =>
    ({
      profile: makeProfile(),
      plan,
      day_number: 1,
      intensity: Intensity.MODERATE,
      body_states: [BodyState.NORMAL],
      eating: Eating.ON_PLAN,
      ...overrides,
    }) as FeedbackDto;

  it('adjusts only the following day and retains plan_id', async () => {
    const { response, isNewPlan } = await service().apply(
      request({ intensity: Intensity.HARD }),
    );
    expect(isNewPlan).toBe(false);
    expect(response.safety_warning).toBeNull();
    expect(response.plan.plan_id).toBe(plan.plan_id);
    expect(response.plan.days[1].workout.duration_minutes).toBe(
      Math.max(10, Math.round(plan.days[1].workout.duration_minutes * 0.75)),
    );
    expect(response.plan.days[0]).toEqual(plan.days[0]);
    expect(response.plan.days[2]).toEqual(plan.days[2]);
  });

  describe('danger sign (#14)', () => {
    it('warns, replaces next workout with rest and skips meal rebalance', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      const { response } = await service(gemini).apply(
        request({
          day_number: 2,
          intensity: Intensity.EASY,
          body_states: [BodyState.DANGER_SIGN],
          eating: Eating.OVER,
        }),
      );
      expect(response.safety_warning).toEqual({
        message: SAFETY_WARNING_MESSAGE,
      });
      expect(response.plan.days[2].workout).toMatchObject(REST_WORKOUT);
      expect(response.plan.days[2].meals).toEqual(plan.days[2].meals);
      expect(generateJson).not.toHaveBeenCalled();
      expect(response.plan.warnings).not.toContain(WARNINGS.mealsNotRebalanced);
    });

    it('applies to day one of the new plan after day-three danger feedback', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      const { response, isNewPlan } = await service(
        gemini,
        new PlanService(gemini),
      ).apply(request({ day_number: 3, body_states: [BodyState.DANGER_SIGN] }));
      expect(isNewPlan).toBe(true);
      expect(response.safety_warning).toEqual({
        message: SAFETY_WARNING_MESSAGE,
      });
      expect(response.plan.days[0].workout).toMatchObject(REST_WORKOUT);
      expect(generateJson).not.toHaveBeenCalled();
    });
  });

  describe('eating feedback', () => {
    it('does not call Gemini when eating was on plan', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      await service(gemini).apply(request());
      expect(generateJson).not.toHaveBeenCalled();
    });

    it('keeps meals and warns when Gemini is not configured', async () => {
      const { response } = await service().apply(
        request({ eating: Eating.OVER }),
      );
      expect(response.plan.days[1].meals).toEqual(plan.days[1].meals);
      expect(response.plan.warnings).toContain(WARNINGS.mealsNotRebalanced);
    });

    it('accepts rebalanced meals within calorie and macro bounds', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      const { response } = await service(gemini).apply(
        request({ eating: Eating.OVER }),
      );
      expect(generateJson).toHaveBeenCalledTimes(1);
      expect(response.plan.days[1].meals.map((meal) => meal.name)).toEqual(
        lighterDay().meals.map((meal) => meal.name),
      );
      expect(response.plan.warnings).not.toContain(WARNINGS.mealsNotRebalanced);
    });

    it.each([
      ['below the BMR floor', meals(300, 480, 500)],
      ['above the target calorie maximum', meals(400, 650, 650)],
    ])(
      'rejects Gemini meals %s and retains existing meals after retries',
      async (_label, invalid) => {
        const { gemini, generateJson } = geminiAnswering(invalid, invalid);
        const { response } = await service(gemini).apply(
          request({ eating: Eating.OVER }),
        );
        expect(generateJson).toHaveBeenCalledTimes(2);
        expect(response.plan.days[1].meals).toEqual(plan.days[1].meals);
        expect(response.plan.warnings).toContain(WARNINGS.mealsNotRebalanced);
      },
    );
  });

  it('creates a new plan on day three and sends only a code-derived feedback note', async () => {
    const generated = await samplePlan();
    const planService = new PlanService(geminiOff);
    const generatePlan = vi
      .spyOn(planService, 'generatePlan')
      .mockResolvedValue(generated);
    const { response, isNewPlan } = await service(geminiOff, planService).apply(
      request({
        day_number: 3,
        intensity: Intensity.HARD,
        body_states: [BodyState.SORE],
        eating: Eating.UNDER,
      }),
    );
    expect(isNewPlan).toBe(true);
    expect(response.plan.plan_id).toBe(generated.plan_id);
    expect(response.plan.plan_id).not.toBe(plan.plan_id);
    expect(generatePlan).toHaveBeenCalledWith(
      expect.objectContaining({ restrictions: expect.any(Object) }),
      {
        feedbackNote:
          'buổi tập rất mệt; căng mỏi cơ; ăn ít hơn thực đơn hoặc bỏ bữa',
      },
    );
  });
});

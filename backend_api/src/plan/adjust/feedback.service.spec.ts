import { geminiAnswering, geminiOff, makeProfile, samplePlan } from '../../../test/plan-fixtures.js';
import type { FeedbackDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { ExerciseTag } from '../enums/exercise.enum.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import { REST_WORKOUT } from '../exercise-presets.js';
import type { GeminiService } from '../gemini.service.js';
import { PlanService } from '../plan.service.js';
import { SAFETY_WARNING_MESSAGE, WARNINGS } from '../plan-warnings.js';
import { FeedbackService } from './feedback.service.js';

const dayTotal = (plan: MealPlanResponseDto, index: number) => plan.days[index].meals.reduce((sum, meal) => sum + meal.calories, 0);

// 3 bữa cho mục tiêu 1624 kcal (BMR 1399); macro chia 25/50/25 nên luôn khớp calo. Mỗi bữa nằm trong khoảng
// của nó (sáng 244–568, trưa/tối 406–731), nên ca nào bị loại là do đúng tổng ngày.
const macros = (calories: number) => ({ protein_g: (calories * 0.25) / 4, carbs_g: (calories * 0.5) / 4, fat_g: (calories * 0.25) / 9 });
const rebalancedDay = (breakfast: number, lunch: number, dinner: number) => ({
  meals: [
    { meal_type: 'breakfast', name: 'Cháo yến mạch táo', portion: '1 bát', calories: breakfast, ...macros(breakfast), ingredients: [{ name: 'Yến mạch', amount: 50, unit: 'g', category: 'pantry' }] },
    { meal_type: 'lunch', name: 'Cơm gạo lứt, gà hấp gừng', portion: '1 chén + 1 đĩa', calories: lunch, ...macros(lunch), ingredients: [{ name: 'Gạo lứt', amount: 90, unit: 'g', category: 'pantry' }] },
    { meal_type: 'dinner', name: 'Canh rau củ đậu phụ non', portion: '1 bát lớn + 1 chén cơm', calories: dinner, ...macros(dinner), ingredients: [{ name: 'Đậu phụ non', amount: 150, unit: 'g', category: 'protein' }] },
  ],
});
const lighterDay = () => rebalancedDay(360, 560, 540); // 1460

describe('FeedbackService', () => {
  let plan: MealPlanResponseDto;

  beforeAll(async () => {
    plan = await samplePlan();
  });

  afterEach(() => vi.restoreAllMocks());

  const service = (gemini: GeminiService = geminiOff) => new FeedbackService(gemini, new PlanService(geminiOff));
  const request = (overrides: Partial<FeedbackDto> = {}): FeedbackDto =>
    ({ profile: makeProfile(), plan, day_number: 1, intensity: Intensity.MODERATE, body_states: [BodyState.NORMAL], eating: Eating.ON_PLAN, ...overrides }) as FeedbackDto;

  it('adjusts only the next day, keeps plan_id and returns no safety warning', async () => {
    const { response, isNewPlan } = await service().apply(request({ intensity: Intensity.HARD }));
    expect(isNewPlan).toBe(false);
    expect(response.safety_warning).toBeNull();
    expect(response.plan.plan_id).toBe(plan.plan_id);
    expect(response.plan.days[1].workout.exercises.map((e) => e.sets)).toEqual(
      plan.days[1].workout.exercises.map((e) => Math.max(1, e.sets - 1)),
    );
    expect(response.plan.days[0]).toEqual(plan.days[0]);
    expect(response.plan.days[2]).toEqual(plan.days[2]);
  });

  describe('danger sign (#14, BRD FR-5.2)', () => {
    it('returns the safety warning and turns the next day into rest, leaving meals alone', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      const { response } = await service(gemini).apply(
        request({ day_number: 2, intensity: Intensity.EASY, body_states: [BodyState.DANGER_SIGN, BodyState.NORMAL], eating: Eating.OVER }),
      );
      expect(response.safety_warning).toEqual({ message: SAFETY_WARNING_MESSAGE });
      expect(response.plan.days[2].workout).toMatchObject({ title: REST_WORKOUT.title, duration_minutes: 15 });
      expect(response.plan.days[2].workout.exercises).toHaveLength(1);
      expect(response.plan.days[2].meals).toEqual(plan.days[2].meals);
      expect(generateJson).not.toHaveBeenCalled();
      expect(response.plan.warnings).not.toContain(WARNINGS.mealsNotRebalanced);
    });

    it('also applies to the first day of the next plan', async () => {
      const { response, isNewPlan } = await service().apply(request({ day_number: 3, body_states: [BodyState.DANGER_SIGN] }));
      expect(isNewPlan).toBe(true);
      expect(response.safety_warning).not.toBeNull();
      expect(response.plan.days[0].workout.title).toBe(REST_WORKOUT.title);
    });
  });

  describe('eating (decision Q3)', () => {
    it('does not call Gemini when the user ate as planned', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      await service(gemini).apply(request());
      expect(generateJson).not.toHaveBeenCalled();
    });

    it('keeps the meals and says so when there is no Gemini key', async () => {
      const { response } = await service().apply(request({ eating: Eating.OVER }));
      expect(response.plan.days[1].meals).toEqual(plan.days[1].meals);
      expect(response.plan.warnings).toContain(WARNINGS.mealsNotRebalanced);
    });

    it('lets Gemini lighten the next day after over-eating, never below BMR (#13)', async () => {
      const { gemini, generateJson } = geminiAnswering(lighterDay());
      const { response } = await service(gemini).apply(request({ eating: Eating.OVER }));
      expect(generateJson).toHaveBeenCalledTimes(1);
      expect(String(generateJson.mock.calls[0][0])).toContain('Tổng calo của ngày khoảng 1462 kcal, trong khoảng 1399–1624');
      expect(response.plan.days[1].meals.map((meal) => meal.meal_id)).toEqual(['m2_1', 'm2_2', 'm2_3']);
      expect(dayTotal(response.plan, 1)).toBe(1460);
      expect(response.plan.warnings).not.toContain(WARNINGS.mealsNotRebalanced);
    });

    it.each([
      ['below BMR (1280 < 1399)', rebalancedDay(300, 500, 480)],
      ['not lighter than the normal target (1700 > 1624)', rebalancedDay(500, 620, 580)],
    ])('rejects a rebalanced day %s, then keeps the old meals', async (_label, bad) => {
      const { gemini, generateJson } = geminiAnswering(bad, bad);
      const { response } = await service(gemini).apply(request({ eating: Eating.OVER }));
      expect(generateJson).toHaveBeenCalledTimes(2);
      expect(response.plan.days[1].meals).toEqual(plan.days[1].meals);
      expect(response.plan.warnings).toContain(WARNINGS.mealsNotRebalanced);
    });
  });

  describe('day 3 → new plan (FR-5.3)', () => {
    it('creates a new plan with a new id and applies the workout rules to its first day', async () => {
      const generatePlan = vi.spyOn(PlanService.prototype, 'generatePlan');
      const { response, isNewPlan } = await service().apply(
        request({ day_number: 3, body_states: [BodyState.JOINT_PAIN], eating: Eating.UNDER }),
      );
      expect(isNewPlan).toBe(true);
      expect(response.plan.plan_id).not.toBe(plan.plan_id);
      expect(generatePlan).toHaveBeenCalledWith(expect.anything(), { feedbackNote: 'buổi tập vừa sức; đau khớp; ăn ít hơn thực đơn hoặc bỏ bữa' });
      const tags = response.plan.days[0].workout.exercises.flatMap((exercise) => exercise.tags);
      expect(tags).not.toContain(ExerciseTag.JUMPING);
      expect(tags).not.toContain(ExerciseTag.KNEELING);
      expect(response.plan.warnings).toContain(WARNINGS.mealsNotRebalanced);
    });
  });
});

import type { CreatePlanDto } from '../dto/create-plan.dto.js';
import type { ExerciseContentDto, MealContentDto } from '../dto/plan-content.dto.js';
import { Eating } from '../enums/feedback.enum.js';
import { MealType } from '../enums/meal-type.enum.js';
import {
  EXERCISE_JSON_SHAPE,
  exerciseCodeRules,
  ingredientCodeRules,
  MACRO_RULE,
  MEAL_JSON_SHAPE,
  mealRules,
  PROMPT_ROLE,
  userDataBlock,
} from '../gemini.service.js';
import type { CalorieRange } from '../plan-validation.js';

// Prompt cho đổi món (FR-4.1), đổi bài tập (FR-4.2), cân đối món ăn sau feedback (FR-5.2).
// Chữ người dùng nhập chỉ nằm trong userDataBlock() (NFR-8). Tên món/động tác lấy từ plan hiện tại.

const EATING_NOTE: Record<Exclude<Eating, Eating.ON_PLAN>, string> = {
  [Eating.OVER]: 'hôm trước ăn nhiều hơn thực đơn — ngày này nhẹ hơn một chút, nhiều rau, ít dầu mỡ, vẫn đủ 3 bữa',
  [Eating.UNDER]: 'hôm trước ăn ít hơn thực đơn hoặc bỏ bữa — ngày này chọn món dễ ăn, đủ chất, không ăn bù',
};

export function buildMealSwapPrompt(
  profile: CreatePlanDto,
  original: MealContentDto,
  range: CalorieRange,
  avoidNames: string[],
): string {
  return [
    PROMPT_ROLE,
    `Nhiệm vụ: đề xuất 1 món thay cho bữa ${original.meal_type} "${original.name}" trong kế hoạch ăn uống.`,
    '',
    ...userDataBlock(profile),
    '',
    'Quy tắc bắt buộc:',
    '- Món ăn gia đình Việt Nam bình dân, dễ mua, dễ nấu.',
    '- Không dùng nguyên liệu người dùng dị ứng; chọn món phù hợp tình trạng sức khoẻ đã khai.',
    `- meal_type là ${original.meal_type}; calories trong khoảng ${range.min}–${range.max}. ${MACRO_RULE}`,
    `- Không trùng các món đã có: ${avoidNames.join('; ')}.`,
    ...ingredientCodeRules(),
    '',
    'Chỉ trả về JSON của 1 món, không kèm giải thích, đúng cấu trúc:',
    MEAL_JSON_SHAPE,
  ].join('\n');
}

export function buildExerciseSwapPrompt(
  profile: CreatePlanDto,
  original: ExerciseContentDto,
  avoidNames: string[],
): string {
  const tags = original.tags.length > 0 ? original.tags.join(', ') : '(để mảng rỗng)';
  return [
    PROMPT_ROLE,
    `Nhiệm vụ: đề xuất 1 động tác NHẸ HƠN để thay "${original.name}" (nhóm cơ ${original.muscle_group}, ${original.sets} hiệp × ${original.reps_or_duration}).`,
    '',
    ...userDataBlock(profile),
    '',
    'Quy tắc bắt buộc:',
    `- Cùng nhóm cơ: muscle_group là ${original.muscle_group}. Bodyweight, không cần dụng cụ.`,
    '- Không chọn động tác gây tải lên vùng chấn thương người dùng đã khai.',
    `- sets không quá ${original.sets}. tags chỉ được chọn trong: ${tags}.`,
    `- Không trùng các động tác đã có trong buổi: ${avoidNames.join('; ')}.`,
    ...exerciseCodeRules(),
    '',
    'Chỉ trả về JSON của 1 động tác, không kèm giải thích, đúng cấu trúc:',
    EXERCISE_JSON_SHAPE,
  ].join('\n');
}

export function buildDayMealsPrompt(
  profile: CreatePlanDto,
  planTargetCalories: number,
  dayNumber: number,
  dayCalories: number,
  range: CalorieRange,
  eating: Exclude<Eating, Eating.ON_PLAN>,
  avoidNames: string[],
): string {
  return [
    PROMPT_ROLE,
    `Nhiệm vụ: lập lại 3 bữa (${Object.values(MealType).join(', ')}) cho ngày ${dayNumber} của kế hoạch ăn uống.`,
    `Lý do: ${EATING_NOTE[eating]}.`,
    '',
    ...userDataBlock(profile),
    '',
    'Quy tắc bắt buộc:',
    '- Món ăn gia đình Việt Nam bình dân, dễ mua, dễ nấu; 3 món khác tên nhau.',
    '- Không dùng nguyên liệu người dùng dị ứng; chọn món phù hợp tình trạng sức khoẻ đã khai.',
    `- Tổng calo của ngày khoảng ${dayCalories} kcal, trong khoảng ${range.min}–${range.max}.`,
    ...mealRules(planTargetCalories),
    `- Không trùng các món của những ngày khác: ${avoidNames.join('; ')}.`,
    '',
    'Chỉ trả về JSON, không kèm giải thích, đúng cấu trúc:',
    `{"meals":[${MEAL_JSON_SHAPE}]}`,
  ].join('\n');
}

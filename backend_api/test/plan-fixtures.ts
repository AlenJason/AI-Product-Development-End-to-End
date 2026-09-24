import { CreatePlanDto } from '../src/plan/dto/create-plan.dto.js';
import type { MealPlanResponseDto } from '../src/plan/dto/meal-plan-response.dto.js';
import { RestrictionsDto } from '../src/plan/dto/restrictions.dto.js';
import { ActivityLevel } from '../src/plan/enums/activity-level.enum.js';
import { Gender } from '../src/plan/enums/gender.enum.js';
import { Goal } from '../src/plan/enums/goal.enum.js';
import type { GeminiService } from '../src/plan/gemini.service.js';
import { PlanService } from '../src/plan/plan.service.js';
import { RandomSource } from '../src/plan/adjust/random-source.js';

// Dữ liệu dùng chung cho test đổi món, đổi bài tập, feedback (giai đoạn 4).

export function makeProfile(
  overrides: Partial<Omit<CreatePlanDto, 'restrictions'>> = {},
  restrictions: Partial<RestrictionsDto> = {},
): CreatePlanDto {
  return Object.assign(new CreatePlanDto(), {
    age: 22,
    gender: Gender.FEMALE,
    height_cm: 168,
    weight_kg: 62,
    activity_level: ActivityLevel.LIGHT,
    goal: Goal.CUT,
    ...overrides,
    restrictions: Object.assign(new RestrictionsDto(), restrictions),
  });
}

export const geminiOff = { isConfigured: false } as unknown as GeminiService;

// Gemini giả cho generateJson(): mỗi phần tử là kết quả của một lần gọi — Error thì ném ra, còn lại thì trả về.
export function geminiAnswering(...answers: unknown[]) {
  const generateJson = vi.fn();
  for (const answer of answers) {
    if (answer instanceof Error) generateJson.mockRejectedValueOnce(answer);
    else generateJson.mockResolvedValueOnce(answer);
  }
  return { gemini: { isConfigured: true, generateJson } as unknown as GeminiService, generateJson };
}

// Plan hợp lệ do chính server tạo (thực đơn mẫu, không Gemini) — giống plan app sẽ gửi lại.
export function samplePlan(profile: CreatePlanDto = makeProfile()): Promise<MealPlanResponseDto> {
  return new PlanService(geminiOff).generatePlan(profile);
}

// Luôn chọn ứng viên đầu tiên (hoặc cuối cùng) để test lặp lại được.
export const firstPick = { next: () => 0 } as RandomSource;
export const lastPick = { next: () => 0.999 } as RandomSource;

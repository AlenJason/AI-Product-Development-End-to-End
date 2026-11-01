import type { GeminiService } from './gemini.service.js';

// One selected instance for all tasks. GeminiService remains a compatibility
// alias in PlanModule; its token name does not identify the runtime provider.
export const PLAN_AI = Symbol('PLAN_AI');
export type PlanAi = Pick<
  GeminiService,
  'isConfigured' | 'budget' | 'generateJson' | 'generatePlanContent'
> & {
  readonly providerName?: 'groq' | 'gemini';
};

export type AiTask = 'meal-swap' | 'exercise-swap' | 'feedback-meals';
export function taskSourceWarning(
  ai: PlanAi,
  task: AiTask,
  success: boolean,
): string[] {
  // Preserve legacy Gemini response fixtures. source describes the initial
  // plan; these warnings describe ONLY the latest adjustment, not every item.
  if (ai.providerName !== 'groq') return [];
  return [
    `[AI:${task}:${success ? 'groq' : 'fallback'}] ${success ? 'Groq đã tạo điều chỉnh hợp lệ.' : 'Không có kết quả Groq hợp lệ; dùng phương án dự phòng đã kiểm tra.'}`,
  ];
}

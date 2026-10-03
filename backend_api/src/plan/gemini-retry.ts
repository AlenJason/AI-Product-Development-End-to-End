import type { Logger } from '@nestjs/common';
import {
  classifyGeminiError,
  type GeminiBudget,
  type GeminiModels,
  type GeminiOutcome,
  geminiHttpStatus,
} from './gemini.service.js';

// Bốn chỗ gọi Gemini — mã cố định để thống kê; nhãn tiếng Việt để ghi log.
export type GeminiTask = 'plan' | 'meal_swap' | 'exercise_swap' | 'feedback';
export const GEMINI_TASK_LABEL: Record<GeminiTask, string> = {
  plan: 'tạo kế hoạch',
  meal_swap: 'đổi món',
  exercise_swap: 'đổi bài tập',
  feedback: 'cân đối món ăn',
};

// Có model dự phòng: tối đa 3 lần gọi lại (quyết định Q4 giai đoạn 10). Không có: gọi lại 1 lần như trước.
export const MAX_GEMINI_ATTEMPTS = 4;
const MAX_ATTEMPTS_WITHOUT_FALLBACK = 2;
// Còn ít hơn chừng này trong giới hạn tổng thì không gọi lại: Gemini thật cần 13 s trở lên cho một plan.
export const MIN_RETRY_MS = 5_000;

export interface ParseResult<T> {
  value: T | null;
  errors: string[];
}

// Một lần gọi Gemini, cho nhật ký Gemini của trang thống kê (giai đoạn 10). `message` chỉ là thông báo ngắn của Google
// hoặc câu chung — không có nội dung Gemini trả về hay chi tiết vi phạm hợp đồng (có thể trích nội dung, #12).
export interface GeminiAttempt {
  task: GeminiTask;
  model: string;
  attempt: number;
  outcome: GeminiOutcome;
  httpStatus?: number;
  durationMs: number;
  message?: string;
}

export interface GeminiCaller {
  budget: GeminiBudget;
  models: GeminiModels;
  // Ghi nhật ký; không được ném lỗi làm hỏng request (StatsService tự bắt lỗi).
  recordAttempt?(attempt: GeminiAttempt): Promise<void>;
}

// Gọi Gemini, kiểm kết quả; lỗi hoặc sai hợp đồng → gọi lại, trừ khi hết giờ (#15, NFR-1). Mọi lần gọi lại chỉ dùng
// phần thời gian còn lại của budget.totalMs, nên người dùng không chờ quá con số đó.
// Chọn model cho lần gọi kế tiếp: quá tải (503), hết lượt (429) hay lỗi khác ở model chính → sang ngay model dự phòng
// (503 tới sau ~20 s — gọi lại đúng model đang quá tải thì model dự phòng không còn đủ thời gian, đo 2026-10-03);
// kết quả hỏng (JSON, sai hợp đồng) → thử lại model chính một lần rồi mới sang dự phòng; đã sang dự phòng thì ở lại.
// Trả null khi không dùng được, nơi gọi tự chuyển sang dữ liệu soạn sẵn.
// Log chỉ ghi thông báo lỗi và vi phạm hợp đồng — `parse` không được đưa chữ người dùng vào `errors` (#12).
export async function generateWithRetry<T>(
  logger: Pick<Logger, 'warn' | 'error'>,
  task: GeminiTask,
  gemini: GeminiCaller,
  call: (timeoutMs: number, model: string) => Promise<unknown>,
  parse: (raw: unknown) => ParseResult<T>,
): Promise<T | null> {
  const { budget, models } = gemini;
  const label = GEMINI_TASK_LABEL[task];
  const maxAttempts = models.fallback ? MAX_GEMINI_ATTEMPTS : MAX_ATTEMPTS_WITHOUT_FALLBACK;
  const deadline = Date.now() + budget.totalMs;
  let model = models.primary;
  let primaryRetried = false;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const remainingMs = deadline - Date.now();
    if (attempt > 1 && remainingMs < MIN_RETRY_MS) {
      logger.warn(`Gemini không gọi lại (${label}): chỉ còn ${remainingMs} ms trong giới hạn ${budget.totalMs} ms.`);
      break;
    }
    const startedAt = Date.now();
    const record = (entry: Omit<GeminiAttempt, 'task' | 'model' | 'attempt' | 'durationMs'>) =>
      gemini.recordAttempt?.({ task, model, attempt, durationMs: Date.now() - startedAt, ...entry });
    let outcome: Exclude<GeminiOutcome, 'ok'>;
    try {
      const { value, errors } = parse(await call(Math.min(budget.perCallMs, remainingMs), model));
      if (value) {
        await record({ outcome: 'ok' });
        return value;
      }
      outcome = 'invalid';
      logger.warn(`Kết quả Gemini không đạt hợp đồng (lần ${attempt}, ${label}, ${model}): ${errors.slice(0, 5).join('; ')}`);
      await record({ outcome, message: `Sai hợp đồng (${errors.length} lỗi)` });
    } catch (error) {
      outcome = classifyGeminiError(error);
      const message = describeGeminiError(error);
      logger.error(`Lỗi khi gọi Gemini (lần ${attempt}, ${label}, ${model}): ${message}`);
      await record({ outcome, httpStatus: geminiHttpStatus(error), message });
    }
    if (outcome === 'timeout') break;
    if (model === models.primary && outcome === 'invalid' && !primaryRetried) {
      primaryRetried = true;
    } else {
      model = models.fallback ?? models.primary;
    }
  }
  return null;
}

const MAX_ERROR_LENGTH = 300;

// ApiError của @google/genai mang nguyên khối JSON Google trả về (kèm mảng details dài) trong message.
// Log chỉ giữ mã lỗi và thông báo chính — vẫn đủ để biết hết hạn mức, khoá sai hay model quá tải.
// Thông báo của Google không chứa khoá hay dữ liệu người dùng.
export function describeGeminiError(error: unknown): string {
  if (!(error instanceof Error)) return String(error);
  const jsonStart = error.message.indexOf('{');
  if (jsonStart >= 0) {
    try {
      const body = JSON.parse(error.message.slice(jsonStart)) as { error?: { code?: number; status?: string; message?: string } };
      if (body.error?.message) {
        const text = body.error.message.replace(/\s+/g, ' ').trim();
        return `${body.error.code ?? ''} ${body.error.status ?? ''} — ${text}`.trim().slice(0, MAX_ERROR_LENGTH);
      }
    } catch {
      // Không phải JSON của Google → dùng nguyên thông báo.
    }
  }
  return error.message.slice(0, MAX_ERROR_LENGTH);
}

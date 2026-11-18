import type { Logger } from '@nestjs/common';
import { type GeminiBudget, GeminiTimeoutError } from './gemini.service.js';
import { GroqRequestError } from './groq-plan.service.js';

export const MAX_GEMINI_ATTEMPTS = 2;
// Còn ít hơn chừng này trong giới hạn tổng thì không gọi lại: Gemini thật cần 13 s trở lên cho một plan.
export const MIN_RETRY_MS = 5_000;

export interface ParseResult<T> {
  value: T | null;
  errors: string[];
}

// Gọi Gemini, kiểm kết quả; sai hợp đồng hoặc lỗi → gọi lại đúng 1 lần, trừ khi hết giờ (#15, NFR-1).
// Lần gọi lại chỉ dùng phần thời gian còn lại của budget.totalMs, nên người dùng không chờ quá con số đó.
// Trả null khi không dùng được, nơi gọi tự chuyển sang dữ liệu soạn sẵn.
// Log chỉ ghi thông báo lỗi và vi phạm hợp đồng — `parse` không được đưa chữ người dùng vào `errors` (#12).
export async function generateWithRetry<T>(
  logger: Pick<Logger, 'warn' | 'error'>,
  task: string,
  budget: GeminiBudget,
  call: (timeoutMs: number) => Promise<unknown>,
  parse: (raw: unknown) => ParseResult<T>,
  provider: 'groq' | 'gemini' = 'gemini',
): Promise<T | null> {
  const deadline = Date.now() + budget.totalMs;
  for (let attempt = 1; attempt <= MAX_GEMINI_ATTEMPTS; attempt++) {
    const remainingMs = deadline - Date.now();
    if (attempt > 1 && remainingMs < MIN_RETRY_MS) {
      logger.warn(
        `AI không gọi lại (${task}): chỉ còn ${remainingMs} ms trong giới hạn ${budget.totalMs} ms.`,
      );
      break;
    }
    try {
      const { value, errors } = parse(
        await call(Math.min(budget.perCallMs, remainingMs)),
      );
      if (value) {
        if (provider === 'groq')
          logger.warn(
            JSON.stringify({
              event: 'ai_task_result',
              provider,
              task,
              attempt,
              source: 'groq',
            }),
          );
        return value;
      }
      logger.warn(
        provider === 'groq'
          ? JSON.stringify({
              event: 'ai_validation_failed',
              provider,
              task,
              attempt,
              error_count: errors.length,
            })
          : `Kết quả AI không đạt hợp đồng (lần ${attempt}, ${task}): ${errors.slice(0, 5).join('; ')}`,
      );
    } catch (error) {
      logger.error(
        provider === 'groq'
          ? JSON.stringify({
              event: 'ai_provider_failed',
              provider,
              task,
              attempt,
              code:
                error instanceof GroqRequestError
                  ? 'HTTP_ERROR'
                  : error instanceof Error &&
                      ['TimeoutError', 'AbortError'].includes(error.name)
                    ? 'TIMEOUT'
                    : 'INVALID_OR_UNAVAILABLE',
              ...(error instanceof GroqRequestError
                ? { status: error.status }
                : {}),
            })
          : `Lỗi khi gọi AI (lần ${attempt}, ${task}): ${describeGeminiError(error)}`,
      );
      if (error instanceof GroqRequestError && error.status < 500) break;
      if (
        error instanceof Error &&
        ['TimeoutError', 'AbortError'].includes(error.name)
      )
        break;
      if (error instanceof GeminiTimeoutError) break;
    }
  }
  if (provider === 'groq')
    logger.warn(
      JSON.stringify({
        event: 'ai_task_result',
        provider,
        task,
        source: 'fallback',
        reason: 'NO_VALID_AI_RESULT',
      }),
    );
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
      const body = JSON.parse(error.message.slice(jsonStart)) as {
        error?: { code?: number; status?: string; message?: string };
      };
      if (body.error?.message) {
        const text = body.error.message.replace(/\s+/g, ' ').trim();
        return `${body.error.code ?? ''} ${body.error.status ?? ''} — ${text}`
          .trim()
          .slice(0, MAX_ERROR_LENGTH);
      }
    } catch {
      // Không phải JSON của Google → dùng nguyên thông báo.
    }
  }
  return error.message.slice(0, MAX_ERROR_LENGTH);
}

import type { Logger } from '@nestjs/common';
import { GeminiTimeoutError } from './gemini.service.js';

export const MAX_GEMINI_ATTEMPTS = 2;

export interface ParseResult<T> {
  value: T | null;
  errors: string[];
}

// Gọi Gemini, kiểm kết quả; sai hợp đồng hoặc lỗi → gọi lại đúng 1 lần, trừ khi hết giờ (#15, NFR-1).
// Trả null khi không dùng được, nơi gọi tự chuyển sang dữ liệu soạn sẵn.
// Log chỉ ghi thông báo lỗi và vi phạm hợp đồng — `parse` không được đưa chữ người dùng vào `errors` (#12).
export async function generateWithRetry<T>(
  logger: Logger,
  task: string,
  call: () => Promise<unknown>,
  parse: (raw: unknown) => ParseResult<T>,
): Promise<T | null> {
  for (let attempt = 1; attempt <= MAX_GEMINI_ATTEMPTS; attempt++) {
    try {
      const { value, errors } = parse(await call());
      if (value) return value;
      logger.warn(`Kết quả Gemini không đạt hợp đồng (lần ${attempt}, ${task}): ${errors.slice(0, 5).join('; ')}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.error(`Lỗi khi gọi Gemini (lần ${attempt}, ${task}): ${message}`);
      if (error instanceof GeminiTimeoutError) break;
    }
  }
  return null;
}
